require 'rubygems'
require 'json'
require 'open-uri'
require 'simple-rss'

consent = [
    { :user => "https://mastodon.me.uk/users/mdales", :consent => "all", :link => "https://a.b.c" }
]

# The easiest way to get recent statuses posted with a tag is to use RSS
tag_url = "https://does.social/tags/weeknotes.rss"

recent_statuses = SimpleRSS.parse(URI.parse(tag_url).read)

recent_statuses.items.each do |s|
    # FIXME check if it's one we've not seen
    if true #s.pubDate would give us the publication date
        # Get the status details
        puts "Fetching #{s.guid}"
        puts "Fetching #{s.link}"
# FIXME This doesn't work for Pleroma URLs (dunno about anything else other than Mastodon)
# FIXME so fails for Matt's posts
        status = JSON.parse(URI.open("#{s.guid}.json").read)

        # See if the user is one we've already had an answer from
        u = consent.index { |x| x[:user] == status["attributedTo"] }
        unless u.nil?
            # We've already heard from them
            if consent[u][:consent] == "all"
                # Save the status for inclusion in the weeknotes
            elsif consent[u][:consent] == "weeknotes"
            else
                puts "We don't have consent for #{s.guid}"
            end
        else
            # We haven't heard from this person
            # FIXME We should keep some sort of pending list
            # FIXME and only ask every now and then (maybe?)
            message = "Hi, we spotted your post #{s.guid} which we'd like to include in our weeknotes blog post.  Can we use it for all things relating to DoES Liverpool; just for weeknotes; or not at all?  Reply [All / Weeknotes / No].  We won't bother you again after this.  Thanks!"
            # Send the message to the user
            puts "#{status['attributedTo']} => #{message}"
        end
    end
end

