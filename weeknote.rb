#!/usr/bin/ruby
#
# Weeknote - simple class to help generating weeknotes blog posts
# (c) Copyright 2013 Adrian McEwen
require 'pp'

class Weeknote
  attr_accessor :created_at, :html

  def initialize(created_at, html)
    @created_at = created_at
    @html = html
  end

  def Weeknote.new_from_tweet(tweet)
    # v5 of the Twitter gem won't let us change "text", so make a copy we can mod
    tweet_text = tweet.full_text.dup
    # Expand any URLs
    tweet.urls.each do |u|
      tweet_text.gsub!(u.url, "<a href=\"#{u.expanded_url}\">#{u.display_url}</a>")
    end
    # Expand any pictures
    tweet.media.each do |m|
      # FIXME This probably won't work when we get a non-picture media type
      if tweet_text.gsub!(m.url, "<a href=\"https://#{m.display_url}\">#{m.display_url}</a> <div class=\"weeknote-image\"><img src=\"#{m.media_url}\" width=\"#{m.sizes[:medium].w}\" height=\"#{m.sizes[:medium].h}\"></div>") == nil
        # We didn't perform any substitution, so this will be one of the
	# additional images (that Twitter doesn't include in the text!)
	tweet_text = tweet_text + " <div class=\"weeknote-image\"><img src=\"#{m.media_url}\" width=\"#{m.sizes[:medium].w}\" height=\"#{m.sizes[:medium].h}\"></div>"
      end
    end
    # Expand any twitter names, using friendly names rather than twitter handles
    tweet.user_mentions.each do |u|
      tweet_text.gsub!("@#{u.screen_name}", "<a href=\"https://twitter.com/#{u.screen_name}\">#{u.name}</a>")
    end
    html = "<li><a href=\"https://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}\">#{tweet.user.name}</a>: #{tweet_text}</li>"
    # Expand any hashtags
    html.gsub!(/#(\w+)/) { "<a href=\"https://twitter.com/search?q=%23#{$1}\">##{$1}</a>" }
    Weeknote.new(tweet.created_at, html)
  end

  def Weeknote.new_from_instagram(media_item)
    item_text = ""
    if media_item["type"] == "image"
      # We can embed this image okay
      pic = media_item.images.standard_resolution
      item_text = "#{media_item.caption.text} <div class=\"weeknote-image\"><img src=\"#{pic.url}\" width=\"#{pic.width}\" height=\"#{pic.height}\"></div>"
    else
      # Just provide a link to videos (for now at least)
      item_text = "<a href=\"#{media_item.link}\">#{media_item.link}</a> #{media_item.caption.text}"
    end
    html = "<li><a href=\"#{media_item.link}\">#{media_item.user.full_name}</a>: #{item_text}</li>"
    # Expand any hashtags
    html.gsub!(/#(\w+)/) { "<a href=\"https://instagram.com/explore/tags/#{$1}/\">##{$1}</a>" }
    Weeknote.new(Time.at(media_item.created_time.to_i), html)
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

