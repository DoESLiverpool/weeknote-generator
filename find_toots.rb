require 'rubygems'
require 'json'
require 'open-uri'
require 'rest-client'

consent = [
    { :user => "mdales@mastodon.me.uk", :consent => "all", :link => "https://a.b.c" }
]

tag_url = "https://does.social/api/v1/timelines/tag/weeknotes"

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

bearer_token = input_settings['mastodon']['bearer_token']


recent_statuses = JSON.parse(URI.open(tag_url, "Authorization" => "Bearer #{bearer_token}").read)

recent_statuses.each do |s|
    # FIXME check if it's one we've not seen
    if true #s['created_at'] would give us the publication date
        # Get the status details

        # See if the user is one we've already had an answer from
        u = consent.index { |x| x[:user] == s["account"]["acct"] }
        unless u.nil?
            # We've already heard from them
            if consent[u][:consent] == "all"
                # Save the status for inclusion in the weeknotes
            elsif consent[u][:consent] == "weeknotes"
            else
                puts "We don't have consent for #{s['url']}"
            end
        else
            # We haven't heard from this person
            # FIXME We should keep some sort of pending list
            # FIXME and only ask every now and then (maybe?)
            message = "Hi, @#{s['account']['acct']}, we spotted your post #{s['url']} which we'd like to include in our weeknotes blog post.  Can we use it for all things relating to DoES Liverpool; just for weeknotes; or not at all?  Reply [All / Weeknotes / No].  We won't bother you again after this.  Thanks!"
            # Send the message to the user
# FIXME For now just spam me :-)
if s['account']['acct'] == "amcewen@mastodon.me.uk"
            puts "Spamming #{s['account']['acct']} => #{message}"
            payload = { status: message, poll: { options: ["all", "just weeknotes", "no"], expires_in: 3600}, visibility: "direct" }
            post_status_url = "https://does.social/api/v1/statuses"
            resp = RestClient.post(post_status_url, payload, { "Authorization": "Bearer #{bearer_token}"})
            puts resp.code
            puts resp.body
else
            puts "#{s['account']['acct']} => #{message}"
end
        end
    end
end

