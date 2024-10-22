#!/usr/bin/ruby
#
# Weeknote - simple class to help generating weeknotes blog posts
# (c) Copyright 2013 Adrian McEwen
require 'pp'
require './utils'

class Weeknote
  attr_accessor :created_at, :html

  def initialize(created_at, html)
    @created_at = created_at
    @html = html
  end

  def Weeknote.new_from_toot(toot, consent, media_site)
    # toot is the filename of a JSON file containing the toot
    t = JSON.load_file(toot)
    media_html = ""
    # Download any images
    # FIXME We should handle video too
    t['media_attachments'].each do |m|
        # Download it
        # Ensure the user's directory exists
        dest_folder = File.join(media_site['root_folder'], consent, t['account']['acct'])
        if ensure_folder_exists(dest_folder)
            # Default to the original URL, but if it's from "our" account (or maybe our server?) then
            # `remote_url` will be blank, and we should use `url` instead then.
            media_url = m['remote_url']
            if media_url.nil?
                media_url = m['url']
            end
            # wget media_url
            dest_file = File.join(dest_folder, File.basename(media_url))
            dest_url = URI.join(media_site['root_url'], File.join(consent, t['account']['acct'], File.basename(media_url)))
            URI.open(media_url) do |remote|
                File.open(dest_file, 'w') do |dest|
                    IO.copy_stream(remote, dest)
                end
            end
        end
        if m['type'] == "image"
            media_html += " <figure class=\"weeknote-image\"><img alt=\"#{m['description']}\" src=\"#{dest_url}\" width=\"#{m['meta']['original']['width']}\" height=\"#{m['meta']['original']['height']}\"></figure>"
        elsif m['type'] == "video"
            media_html += " <figure class=\"weeknote-image\"><video width=\"100%\" controls=\"controls\" loop autoplay=\"false\"><source type=\"video/mp4\" src=\"#{dest_url}\"></source><p>#{m['description']}</p></video></figure>"
        end
    end
    username = t["account"]["display_name"]
    html = "<li><a href=\"#{t['url']}\">#{username}</a>: #{t['content']} #{media_html}</li>"
    Weeknote.new(t['created_at'], html)
  end

  def Weeknote.new_from_tweet(tweet)
    # v5 of the Twitter gem won't let us change "text", so make a copy we can mod
    tweet_text = tweet.attrs[:full_text].dup
    # Expand any URLs
    tweet.urls.each do |u|
      tweet_text.gsub!(u.url, "<a href=\"#{u.expanded_url}\">#{u.display_url}</a>")
    end
    # Expand any pictures
    tweet.media.each do |m|
      # FIXME This probably won't work when we get a non-picture media type
      if tweet_text.gsub!(m.url, "<a href=\"https://#{m.display_url}\">#{m.display_url}</a> <div class=\"weeknote-image\"><img src=\"#{m.media_url_https}\" width=\"#{m.sizes[:medium].w}\" height=\"#{m.sizes[:medium].h}\"></div>") == nil
        # We didn't perform any substitution, so this will be one of the
	# additional images (that Twitter doesn't include in the text!)
	tweet_text = tweet_text + " <div class=\"weeknote-image\"><img src=\"#{m.media_url_https}\" width=\"#{m.sizes[:medium].w}\" height=\"#{m.sizes[:medium].h}\"></div>"
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

