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

start_of_last_week = (Time.now.start_of_work_week-1.day).start_of_work_week
end_of_last_week = start_of_last_week.end_of_work_week
start_of_this_week = Time.now.start_of_work_week
end_of_this_week = Time.now.end_of_work_week

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
  'title' => 'Week X',
  'description' => content,
  'mt_keywords' => ['weeknotes'],
  'categories' => ['weeknotes'],
  'post_status' => 'draft'
}

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

puts "Done."
