#!/usr/bin/ruby
# generate-weeknotes
# Script to find mentions of #weeknotes on @DoESLiverpool's @mentions stream
# and in the #doesliverpool IRC channel, then output them in a format ready
# to go in a weeknotes blog post

require 'rubygems'
require 'xmlrpc/client'
require 'net/smtp'
require 'twitter'
require 'twitter_keys'
require 'time'
require 'ri_cal'
require 'net/https'
require 'json'
require 'time_start_and_end_extensions'
require 'weeknote'
require 'weeknote_event'
require 'local_config'

# FIXME Not ideal, we should really check the cert, but this gets round
# FIXME a server issue
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Function to work out which week this is
# If your company/project/whatever started on registration_date, this will
# return the correct week number on the date day_to_check
# Both registration_date and day_to_check must be of type Date
def week_on_date(registration_date, day_to_check)
  # Get the start of the week for each of those dates
  if registration_date.wday == 0
    # wday of 0 is Sunday, and we want our weeks to start on Monday
    registration_date = registration_date - 6
  else
    registration_date = registration_date - (registration_date.wday - 1)
  end
  
  if day_to_check.wday == 0
    day_to_check = day_to_check - 6
  else
    day_to_check = day_to_check - (day_to_check.wday - 1)
  end
  
  (((day_to_check - registration_date)/7)+1)
end

start_of_last_week = (Time.now.start_of_work_week-1.day).start_of_work_week
end_of_last_week = start_of_last_week.end_of_work_week
start_of_this_week = Time.now.start_of_work_week
end_of_this_week = Time.now.end_of_work_week

# Work out which week we're generating the weeknotes for
week_number = week_on_date(FOUNDING_DATE, Date.parse(start_of_last_week.to_s))

puts
puts "Week #{week_number}"
(week_number.to_s.length+5).times { putc '-' }
puts
puts
puts "Weeknotes from "+start_of_last_week.to_s+" to "+end_of_last_week.to_s
puts "Calendar from "+start_of_this_week.to_s+" to "+end_of_this_week.to_s

# Start off with no weeknotes
weeknotes = []

#
# Get Twitter weeknotes
#

puts "Checking Twitter..."
twitter_client = Twitter::REST::Client.new do |config|
  config.consumer_key = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET
  config.access_token = TWITTER_OAUTH_KEY
  config.access_token_secret = TWITTER_OAUTH_SECRET
end
twitter_client.search("#weeknotes", :count => 100, :result_type => "recent").each do |tweet|
  if tweet.created_at >= start_of_last_week && tweet.created_at <= end_of_last_week
    if tweet.user.following? || tweet.user.id == TWITTER_USER_ID
      # It's a tweet in the past week containing "#weeknotes",
      # from someone we're following (or from us!)
      weeknotes.push(Weeknote.new_from_tweet(tweet))
    end
  end
end

#
# Add IRC weeknotes
#
puts "Checking IRC..."
irc_weeknotes = `grep -i \#weeknotes #{IRC_LOGFILE}`
irc_weeknotes.split("\n").each do |wn|
  wn_info = wn.match(/\[(\d+\/\d+\/\d+ \d+:\d+:\d+)\] (.*)/)
  if wn_info
    created_at = Time.parse(wn_info[1])
    if created_at >= start_of_last_week && created_at <= end_of_last_week
      weeknotes.push(Weeknote.new_from_irc(created_at, wn_info[2]))
    end
  end
end

# Sort the weeknotes by date/time
weeknotes.sort! { |a, b| a.created_at <=> b.created_at }

# Get upcoming calendar events
events = []
# Download and parse the calendar
if (CAL_URL_IS_HTTPS)
  cal_uri = URI.parse(CAL_URL)
  cal_http = Net::HTTP.new(cal_uri.host, 443)
  cal_http.use_ssl = true
  cal_req = Net::HTTP::Get.new(cal_uri.request_uri)
  cal_data = cal_http.request(cal_req)
else
  cal_data = Net::HTTP.get_response(URI.parse(CAL_URL))
end
all_events = RiCal.parse_string(cal_data.body)
# Find any relevant events
all_events.each do |cal|
  cal.events.each do |ev|
    event_start = ev.start_time
    recurring_occurrence = nil
    if ev.recurs?
      # This is a recurring event, so work out the start of the next occurrence
      next_occurrence = ev.occurrences(:count => 1, :starting => start_of_this_week)
      unless next_occurrence.empty?
        event_start = next_occurrence[0].start_time
        recurring_occurrence = next_occurrence[0]
      end
    end
    # Crude type conversion because event times are DateTime objects
    # and the [start|end]_of_this_week variables are Time objects
    event_start = Time.parse(event_start.to_s)
    if event_start >= start_of_this_week && event_start <= end_of_this_week
      events.push(WeeknoteEvent.new_from_ical(ev, recurring_occurrence))
    end
  end
end
# Sort the events by start date/time
events.sort! { |a, b| a.start_time <=> b.start_time }

# Start with no issues opened or closed
new_issues = []
closed_issues = []
issue_closers = []
open_count = 0
closed_count = 0

# Download all the issues.  They're paginated, so we need to make multiple requests
issues = []
page_num = 1
  
while page_num == 1 || issues.size > 0
  # We want open and closed issues, and they're paginated
  url_params = "?state=all&page=#{page_num}"
  if (ISSUE_URL_IS_HTTPS)
    issue_uri = URI.parse(ISSUE_URL+url_params)
    issue_http = Net::HTTP.new(issue_uri.host, issue_uri.port)
    issue_http.use_ssl = true
    issue_req = Net::HTTP::Get.new(issue_uri.request_uri, {'User-Agent' => "weeknote-generator/1.0"})
    issue_data = issue_http.request(issue_req)
  else
    issue_data = Net::HTTP.get_response(URI.parse(ISSUE_URL+url_params))
  end
  
  issues = JSON.parse(issue_data.body)
  
  issues.each do |issue|
    #puts issue.inspect
    created_at = Time.parse(issue["created_at"])
    if created_at <= end_of_last_week
      # Only count issues that existed last week
      if issue["closed_at"].nil?
        open_count += 1
      else
        closed_count += 1
      end
    end
    if created_at >= start_of_last_week && created_at <= end_of_last_week
      new_issues.push(issue)
    end
    closed_at = nil || issue["closed_at"] && Time.parse(issue["closed_at"])
    if closed_at && closed_at >= start_of_last_week && closed_at <= end_of_last_week
      closed_issues.push(issue)
      # Find out who closed it
      detail_uri = URI.parse(issue["url"])
      puts detail_uri.inspect
      detail_http = Net::HTTP.new(detail_uri.host, detail_uri.port)
      detail_http.use_ssl = true
      detail_req = Net::HTTP::Get.new(detail_uri.request_uri, {'User-Agent' => "weeknote-generator/1.0"})
      detail_data = detail_http.request(detail_req)
      detail = JSON.parse(detail_data.body)
      puts detail["closed_by"]["login"]
      issue_closers.push(detail["closed_by"])
    end
  end

  # Move onto the next page
  page_num += 1
end

# Output blog post data
puts "Saving draft blog post..."
content = "<p><em>Each week we'll endeavour to publish some details of the interesting things that members of DoES Liverpool have been up to over the past seven days.  You can find out a bit more about them in <a href=\"http://doesliverpool.com/uncategorized/talking-about-ourselves/\">our introductory post</a>.</em></p>"
content = content + "\n<p><em>And remember, if you're involved with DoES Liverpool at all, let us know what you get up to so we can include it here!</em></p>"
content = content + "\n<h3>Things of Note</h3>"
content = content + "\n<ul>"
weeknotes.each do |w|
  content = content + "\n" + w.html
end
content = content + "\n</ul>"
content = content + "\n<h3>Coming Up in the Next Week</h3>"
content = content + "\n<table>"
events.each do |ev|
  content = content + "\n" + ev.html
end
content = content + "\n</table>"
content = content + "\n<h3>Somebody Should</h3>"
content = content + "\n<p>The DoES Liverpool to-do list is stored in the <a href='https://github.com/DoESLiverpool/somebody-should/issues'>issues of our Somebody Should repository</a> on github. Head over there if there's something you'd like to report, or if you want to help out fixing things.</p>"
content = content + "\n<p>Issue counts: #{open_count} open, #{closed_count} closed</p>"
if new_issues.empty?
  content = content + "\n<p>No new issues</p>"
else
  if new_issues.size == 1
    content = content + "\n<p>#{new_issues.size} new issue:"
  else
    content = content + "\n<p>#{new_issues.size} new issues:"
  end
  content = content + "\n<ul>"
  new_issues.each do |i|
    url = i["html_url"]
    title = i["title"]
    if i["closed_at"].nil?
      content = content + "\n  <li><a href='#{url}'>#{title}</a></li>"
    else
      content = content + "\n  <li><strike><a href='#{url}'>#{title}</a></strike></li>"
    end
  end
  content = content + "\n</ul>"
end

if closed_issues.empty?
  content = content + "\n<p>No issues closed</p>"
else
  if closed_issues.size == 1
    content = content + "\n<p>#{closed_issues.size} issue closed:"
  else
    content = content + "\n<p>#{closed_issues.size} issues closed:"
  end
  content = content + "\n<ul>"
  closed_issues.each do |i|
    url = i["html_url"]
    title = i["title"]
    content = content + "\n  <li><strike><a href='#{url}'>#{title}</a></strike></li>"
  end
  content = content + "\n</ul>"
  # Thank the people who closed things
  content = content + "\n<p>Thanks " + issue_closers.uniq.collect { |c| "<a href='"+c["html_url"]+"'>"+c["login"]+"</a>" }.join(", ") + "!</p>"
end


# Post it up as a draft post
post = {
  'title' => 'Week '+week_number.to_s,
  'description' => content,
  'mt_keywords' => ['weeknotes'],
  'categories' => ['weeknotes'],
  'post_status' => 'draft'
}

if TESTING == true
  puts
  puts "########### TESTING ############"
  puts "We aren't going to generate a blog post"
  puts "However, it would've looked like this:"
  puts
  puts post["title"]
  post["title"].length.times { putc '-' }

  puts
  puts post["description"]
  puts
else
  # initialize the connection
  connection = XMLRPC::Client.new(BLOG_SERVER, BLOG_XMLRPC_ENDPOINT)
  
  # make the call to publish a new post
  connection.call(
    'metaWeblog.newPost',
    1,
    BLOG_USERNAME,
    BLOG_PASSWORD,
    post,
    true
  )

  # And inform whoever needs to go and put the blog post live
  message = <<MESSAGE_END
From: #{MAIL_LONG_FROM_ADDRESS}
To: #{MAIL_LONG_NOTIFY_ADDRESS}
MIME-Version: 1.0
Content-Type: text/html
Subject: Weeknotes for Week #{week_number} are ready

<p>I've prepared the weeknotes for this week.  Someone needs to log into <a href="http://doesliverpool.com/wp-admin/edit.php">http://doesliverpool.com/wp-admin/edit.php</a>, check them over (particularly the calendar section), come up with a better title, and publish the blog post.</p>

<p>Then tweet about it from @DoESLiverpool and cut-and-paste the weeknotes blog post into an email to the DoES Liverpool Google Group.</p>
MESSAGE_END

  smtp = Net::SMTP.new MAIL_SERVER, MAIL_PORT
  smtp.enable_starttls
  smtp.start(MAIL_DOMAIN, MAIL_USER, MAIL_PASS, MAIL_AUTHTYPE) do
    smtp.send_message message, MAIL_FROM_ADDRESS, MAIL_NOTIFY_ADDRESS
  end
end

puts "Done."
