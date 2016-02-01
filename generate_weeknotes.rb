#!/usr/bin/ruby
#encoding: utf-8
# generate-weeknotes
# Script to find mentions of #weeknotes on @DoESLiverpool's @mentions stream
# and in the #doesliverpool IRC channel, then output them in a format ready
# to go in a weeknotes blog post

require 'rubygems'
require 'yaml'
require 'xmlrpc/client'
require 'net/smtp'
require 'twitter'
require 'instagram'
require 'time'
require 'ri_cal'
require 'net/https'
require 'json'
require './time_start_and_end_extensions'
require './weeknote'
require './weeknote_event'

# Read in config
settings = nil
if ARGV.length == 1
  settings = YAML.load_file(ARGV[0])
else
  puts "No configuration provided."
  exit
end
input_settings = settings["input"]
output_settings = settings["output"]

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
  (((day_to_check - registration_date).to_i/7)+1)
end

start_of_last_week = nil
end_of_last_week = nil
start_of_this_week = nil
end_of_this_week = nil
if settings["immediately_previous_seven_days"] == true
  # The seven days leading up to when the script is running
  start_of_last_week = (Time.now.start_of_day-8.days)
  end_of_last_week = (start_of_last_week+7.days).end_of_day
  start_of_this_week = Time.now.start_of_day
  end_of_this_week = Time.now.start_of_day+7.days
else
  # The previous full week (Mon-Sun)
  start_of_last_week = (Time.now.start_of_work_week-1.day).start_of_work_week
  end_of_last_week = start_of_last_week.end_of_work_week
  start_of_this_week = Time.now.start_of_work_week
  end_of_this_week = Time.now.end_of_work_week
end

# Work out which week we're generating the weeknotes for
week_number = week_on_date(Date.parse(settings['founding_date']), Date.parse(start_of_last_week.to_s))

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
unless input_settings["twitter"].nil?
  puts "Checking Twitter..."
  twitter_client = Twitter::REST::Client.new do |config|
    config.consumer_key = input_settings["twitter"]["consumer_key"]
    config.consumer_secret = input_settings["twitter"]["consumer_secret"]
    config.access_token = input_settings["twitter"]["oauth_key"]
    config.access_token_secret = input_settings["twitter"]["oauth_secret"]
  end
  settings["tags"].each do |tag|
    twitter_client.search("##{tag}", :count => 100, :result_type => "recent").each do |tweet|
      if tweet.created_at >= start_of_last_week && tweet.created_at <= end_of_last_week
        if tweet.user.following? || tweet.user.id == input_settings["twitter"]["id"]
          # It's a tweet in the past week containing "#weeknotes",
          # from someone we're following (or from us!)
          weeknotes.push(Weeknote.new_from_tweet(tweet))
        end
      end
    end
  end
end

#
# Get Instagram weeknotes
#
unless input_settings["instagram"].nil?
  puts "Checking Instagram mentions..."
  Instagram.configure do |config|
    config.client_id = input_settings["instagram"]["client_id"]
    config.client_secret = input_settings["instagram"]["client_secret"]
  end
  # First time round, go to the URL output below
  #puts Instagram.authorize_url(:redirect_uri => "http://doesliverpool.com")
  #exit
  # And then, once authorized, copy the code in the redirected URL into input_settings["instagram"]["auth_code"]
  # It will have been of the form http://doesliverpool.com/?code=<code is here>
  
  # Second time through run this code, to get an access token, and save it for later use
  #response = Instagram.get_access_token(input_settings["instagram"]["auth_code"], :redirect_uri => "http://doesliverpool.com")
  #puts response.access_token.inspect
  #exit
  
  # Then normal usage is just to use the access token we've saved
  client = Instagram.client(:access_token => input_settings["instagram"]["access_token"])
  settings["tags"].each do |tag|
    for media_item in client.tag_recent_media(tag)
      created_time = Time.at(media_item.created_time.to_i)
      if created_time >= start_of_last_week && created_time <= end_of_last_week
        # It's a media_item in the past week containing "#weeknotes"
        weeknotes.push(Weeknote.new_from_instagram(media_item))
      end
    end
  end
end


#
# Add IRC weeknotes
#
unless input_settings["irc_logfile"].nil?
  puts "Checking IRC..."
  settings["tags"].each do |tag|
    irc_weeknotes = `grep -i \##{tag} #{input_settings["irc_logfile"]}`
    irc_weeknotes.split("\n").each do |wn|
      wn_info = wn.match(/\[(\d+\/\d+\/\d+ \d+:\d+:\d+)\] (.*)/)
      if wn_info
        created_at = Time.parse(wn_info[1])
        if created_at >= start_of_last_week && created_at <= end_of_last_week
          weeknotes.push(Weeknote.new_from_irc(created_at, wn_info[2]))
        end
      end
    end
  end
end

# Sort the weeknotes by date/time
weeknotes.sort! { |a, b| a.created_at <=> b.created_at }

# Get upcoming calendar events
events = []
unless input_settings["calendar"].nil?
  # Download and parse the calendar
  if (input_settings["calendar"]["url_is_https"])
    cal_uri = URI.parse(input_settings["calendar"]["url"])
    cal_http = Net::HTTP.new(cal_uri.host, 443)
    cal_http.use_ssl = true
    cal_req = Net::HTTP::Get.new(cal_uri.request_uri)
    cal_data = cal_http.request(cal_req)
  else
    cal_data = Net::HTTP.get_response(URI.parse(input_settings["calendar"]["url"]))
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
unless input_settings["issues"].nil?
  issues = []
  page_num = 1
    
  while page_num == 1 || issues.size > 0
    # We want open and closed issues, and they're paginated
    url_params = "?state=all&page=#{page_num}"
    if (input_settings["issues"]["url_is_https"])
      issue_uri = URI.parse(input_settings["issues"]["url"]+url_params)
      issue_http = Net::HTTP.new(issue_uri.host, issue_uri.port)
      issue_http.use_ssl = true
      issue_req = Net::HTTP::Get.new(issue_uri.request_uri, {'User-Agent' => "weeknote-generator/1.0"})
      issue_data = issue_http.request(issue_req)
    else
      issue_data = Net::HTTP.get_response(URI.parse(input_settings["issues"]["url"]+url_params))
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
        #puts detail_uri.inspect
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
end

# Output blog post data
puts "Saving draft blog post..."
content = output_settings["preambles"]["intro"]
unless weeknotes.empty?
  content = content + "\n<h3>Things of Note</h3>"
  content = content + "\n<ul class=\"weeknotes\">"
  weeknotes.each do |w|
    content = content + "\n" + w.html.force_encoding("UTF-8")
  end
  content = content + "\n</ul>"
end
unless input_settings["calendar"].nil?
  content = content + "\n<h3>Coming Up in the Next Week</h3>"
  content = content + "\n<table>"
  events.each do |ev|
    content = content + "\n" + ev.html.force_encoding("UTF-8")
  end
  content = content + "\n</table>"
end
unless input_settings["issues"].nil?
  content = content + "\n#{output_settings["preambles"]["issues"]}"
  content = content + "\n<p>Issue counts: #{open_count} open, #{closed_count} closed</p>"
  if new_issues.empty?
    content = content + "\n<p>No new issues</p>"
  else
    if new_issues.size == 1
      content = content + "\n<p>#{new_issues.size} new issue:</p>"
    else
      content = content + "\n<p>#{new_issues.size} new issues:</p>"
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
      content = content + "\n<p>#{closed_issues.size} issue closed:</p>"
    else
      content = content + "\n<p>#{closed_issues.size} issues closed:</p>"
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
end

# Add a note on how to send blog posts for publishing
content = content + "\n#{output_settings["preambles"]["outro"]}"

# Work out the title
title = output_settings["title"]
title.gsub!(/\#\{week_number\}/, week_number.to_s)
title.gsub!(/\#\{today\}/, Date.today.to_s)
title.gsub!(/\#\{yesterday\}/, (Date.today - 1).to_s)
# Post it up as a draft post
post = {
  'title' => title,
  'description' => content,
  'mt_keywords' => ['weeknotes'],
  'categories' => ['weeknotes'],
  'post_status' => 'draft'
}

if settings["testing"] == true
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
  unless output_settings["blog_server"].nil?
    # initialize the connection
    connection = XMLRPC::Client.new(output_settings["blog_server"]["server"], output_settings["blog_server"]["xmlrpc_endpoint"])
    
    # make the call to publish a new post
    connection.call(
      'metaWeblog.newPost',
      1,
      output_settings["blog_server"]["username"],
      output_settings["blog_server"]["password"],
      post,
      true
    )
  end

  unless output_settings["blog_folder"].nil?
    filename = post["title"].gsub(/ /, "-").downcase
    File.open("#{output_settings['blog_folder']}#{filename}.html", "w") do |draft|
      draft.puts "---"
      draft.puts "layout: post"
      draft.puts "title: #{post['title']}"
      draft.puts "category: #{post['categories']}"
      draft.puts "tag: [#{settings['tags'].join(',')}]"
      draft.puts "---"
      draft.puts post['description']
    end
  end

  unless output_settings["mail"].nil?
    # And inform whoever needs to go and put the blog post live
    message = <<MESSAGE_END
From: #{output_settings["mail"]["long_from_address"]}
To: #{output_settings["mail"]["long_notify_addresses"].join(",")}
MIME-Version: 1.0
Content-Type: text/html
Subject: #{output_settings["mail"]["subject"]} for Week #{week_number} are ready

#{output_settings["mail"]["body"]}
MESSAGE_END
    smtp = Net::SMTP.new output_settings["mail"]["server"], output_settings["mail"]["port"]
    smtp.enable_starttls
    smtp.start(output_settings["mail"]["domain"], output_settings["mail"]["user"], output_settings["mail"]["password"], :login) do
      smtp.send_message message, output_settings["mail"]["from_address"], output_settings["mail"]["notify_addresses"]
    end
  end
end

puts "Done."
