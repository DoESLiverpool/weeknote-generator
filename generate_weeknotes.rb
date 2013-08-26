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
require 'time_start_and_end_extensions'
require 'weeknote'
require 'weeknote_event'
require 'local_config'

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

puts "Checking Twitter mentions..."
Twitter.configure do |config|
  config.consumer_key = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET
  config.oauth_token = TWITTER_OAUTH_KEY
  config.oauth_token_secret = TWITTER_OAUTH_SECRET
end
# Get as many @mentions as we can
Twitter.mentions_timeline(:count => 200).each do |mention|
  if mention.created_at >= start_of_last_week && mention.created_at <= end_of_last_week
    # This is a mention we might be interested in
    if mention.text.match(/#weeknotes/)
      # It's a mention in the past week containing "#weeknotes"
      weeknotes.push(Weeknote.new_from_tweet(mention))
    end
  end
end

puts "Checking own tweets..."
# Get as many @mentions as we can
Twitter.user_timeline(:count => 200).each do |mention|
  if mention.created_at >= start_of_last_week && mention.created_at <= end_of_last_week
    # This is a mention we might be interested in
    if mention.text.match(/#weeknotes/)
      # It's a mention in the past week containing "#weeknotes"
      weeknotes.push(Weeknote.new_from_tweet(mention))
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
