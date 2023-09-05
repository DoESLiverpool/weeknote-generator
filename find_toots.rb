require 'rubygems'
require 'json'
require 'yaml'
require 'open-uri'
require 'rest-client'

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

consent = YAML.load_file(input_settings['mastodon']['consent_file'])

recent_statuses = JSON.parse(URI.open(tag_url, "Authorization" => "Bearer #{bearer_token}").read)

consent_required = {}
recent_statuses.each do |s|
    # FIXME check if it's one we've not seen
    if true #s['created_at'] would give us the publication date
        # Get the status details

        # See if the user is one we've already had an answer from
        u = consent.index { |x| x[:user] == s["account"]["acct"] }
        unless u.nil?
            # We've already heard from them
            if consent[u][:consent] == "all"
                # FIXME Save the status for inclusion in the weeknotes
            elsif consent[u][:consent] == "weeknotes"
                # FIXME Save the status for inclusion in the weeknotes
            else
                puts "We don't have consent for #{s['url']}"
            end
        else
            # We haven't heard from this person
            if consent_required[s['account']['acct']].nil?
                # Set up the array
                consent_required[s['account']['acct']] = []
            end
            consent_required[s['account']['acct']].push(s)
            # FIXME We should save this status in a consent-pending area
        end
    end
end

unless consent_required.empty?
    # We've got some people to ask for consent
    consent_required.keys.each do |u|
        # Collect the URLs for their relevant toots
        toots = consent_required[u].collect { |t| t['url'] }.join(", ")
        toots_plural = consent_required[u].length > 1 ? "s" : ""
        # FIXME and only ask every now and then (maybe?)
        message = "Hi, @#{u}, we spotted your post#{toots_plural} #{toots} which we'd like to include in our weeknotes blog post.  Can we use it for all things relating to DoES Liverpool; just for weeknotes; or not at all?  Vote or reply [All / Weeknotes / No].  We won't bother you again after this.  Thanks!"
        # Send the message to the user
# FIXME For now just spam me :-)
if u == "amcewen@mastodon.me.uk"
        puts "Spamming #{u} => #{message}"
        payload = { status: message, poll: { options: ["all", "just weeknotes", "no"], expires_in: 3600}, visibility: "direct" }
        post_status_url = "https://does.social/api/v1/statuses"
        resp = RestClient.post(post_status_url, payload, { "Authorization": "Bearer #{bearer_token}"})
        if resp.code == 200
            consent_req = JSON.parse(resp.body)
            puts "#{u} - request #{consent_req['id']}"
            consent.push({ :user => u, :consent => nil, :consent_request => consent_req['id'] })
        else
            puts "Error sending consent request to #{u}: #{message}"
            puts resp.code
            puts resp.body
        end
else
        puts "#{u} => #{message}"
end
    end

    # We'll have asked folk for consent, so update the database
    File.open(input_settings['mastodon']['consent_file'], "w") do |f|
        f.write(consent.to_yaml)
    end
end

