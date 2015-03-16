#!/usr/bin/ruby
#
# Weeknote - simple class to help generating weeknotes blog posts
# (c) Copyright 2013 Adrian McEwen

class Weeknote
  attr_accessor :created_at, :html

  def initialize(created_at, html)
    @created_at = created_at
    @html = html
  end

  def Weeknote.new_from_tweet(tweet)
    # Expand any URLs
    tweet.urls.each do |u|
      tweet.text.gsub!(u.url, "<a href=\"#{u.expanded_url}\">#{u.display_url}</a>")
    end
    # Expand any pictures
    tweet.media.each do |m|
      # FIXME This probably won't work when we get a non-picture media type
      tweet.text.gsub!(m.url, "<a href=\"http://#{m.display_url}\">#{m.display_url}</a> <img src=\"#{m.media_url}\" width=\"#{m.sizes[:medium].w}\" height=\"#{m.sizes[:medium].h}\">")
    end
    # Expand any twitter names, using friendly names rather than twitter handles
    tweet.user_mentions.each do |u|
      tweet.text.gsub!("@#{u.screen_name}", "<a href=\"http://twitter.com/#{u.screen_name}\">#{u.name}</a>")
    end
    html = "<li><a href=\"https://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}\">#{tweet.user.name}</a>: #{tweet.text}</li>"
    # Expand any hashtags
    html.gsub!(/#(\w+)/) { "<a href=\"https://twitter.com/search?q=%23#{$1}\">##{$1}</a>" }
    Weeknote.new(tweet.created_at, html)
  end

  def Weeknote.new_from_irc(created_at, content)
    # HTML escape any <, > and &
    content.gsub!(/&/, "&amp;")
    content.gsub!(/>/, "&gt;")
    content.gsub!(/</, "&lt;")
    # Expand URLs
    content.gsub! /((https?:\/\/|www\.)([-\w\.]+)+(:\d+)?(\/([\-\w\/_\.]*(\?\S+)?)?)?)/, %Q{<a href="\\1">\\1</a>}
    Weeknote.new(created_at, "<li>"+content+"</li>")
  end
end

