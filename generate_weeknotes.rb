#!/usr/bin/ruby
# generate-weeknotes
# Script to find mentions of #weeknotes on @DoESLiverpool's @mentions stream
# and in the #doesliverpool IRC channel, then output them in a format ready
# to go in a weeknotes blog post

require 'rubygems'
require 'xmlrpc/client'
require 'twitter'
require 'twitter_keys'
require 'time'
require 'ri_cal'
require 'time_start_and_end_extensions'
require 'weeknote'
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

puts "Checking Twitter..."
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
puts "Not checking calendar yet"

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
end

puts "Done."
