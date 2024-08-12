require 'rubygems'
require 'json'
require 'yaml'
require 'open-uri'
require 'uri'
require 'rest-client'
require './utils'

start_time = Time.now

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

TAG_URL = "#{input_settings['mastodon']['site']}/api/v1/timelines/tag/weeknotes"
FOLLOWING_URL = "#{input_settings['mastodon']['site']}/api/v1/accounts/relationships?id[]="

consent = []
begin
    consent = YAML.load_file(input_settings['mastodon']['consent_file'])
rescue Exception => e
    puts "Couldn't load consent file #{input_settings['mastodon']['consent_file']}, error #{e.inspect}"
end

recent_statuses = JSON.parse(URI.open(TAG_URL, "Authorization" => "Bearer #{bearer_token}").read)

# Save the toot given in toot in the folder given in location
def save_toot(toot, location)
    filebase = URI(toot["uri"]).hash.to_s
    File.write File.join(location, "#{filebase}.json"), JSON.pretty_generate(toot)
end

def are_we_following?(auth, user_id)
    relationship = JSON.parse(URI.open(FOLLOWING_URL+user_id, "Authorization" => "Bearer #{auth}").read)
    relationship && !relationship.empty? && relationship[0]['following'] == true
end


# Make sure the relevant folders we want exist
ensure_folder_exists(input_settings['mastodon']['consent_folder']) or die "Problem with setting for #{input_settings['mastodon']['consent_folder']}"
ensure_folder_exists(input_settings['mastodon']['publication_folder']) or die "Problem with setting for #{input_settings['mastodon']['publication_folder']}"
ensure_folder_exists("#{input_settings['mastodon']['publication_folder']}/all") or die "Problem with setting for #{input_settings['mastodon']['publication_folder']}/all"
ensure_folder_exists("#{input_settings['mastodon']['publication_folder']}/weeknotes") or die "Problem with setting for #{input_settings['mastodon']['publication_folder']}/weeknotes"
ensure_folder_exists("#{input_settings['mastodon']['published_folder']}/weeknotes") or die "Problem with setting for #{input_settings['mastodon']['published_folder']}/weeknotes"
ensure_folder_exists("#{input_settings['mastodon']['published_folder']}/weeknotes") or die "Problem with setting for #{input_settings['mastodon']['published_folder']}/all"
ensure_folder_exists("#{input_settings['mastodon']['media_site']['root_folder']}/weeknotes") or die "Problem with setting for #{input_settings['mastodon']['media_site']['root_folder']}/weeknotes"
ensure_folder_exists("#{input_settings['mastodon']['media_site']['root_folder']}/all") or die "Problem with setting for #{input_settings['mastodon']['media_site']['root_folder']}/all"

consent_required = {}
recent_statuses.each do |s|
    if are_we_following?(bearer_token, s['account']['id'])
        # Check if it's one we've not seen
        if Time.parse(s['created_at']) >= start_time - input_settings['mastodon']['check_frequency']
            # Get the status details

            # See if the user is one we've already had an answer from
            u = consent.index { |x| x[:user] == s["account"]["acct"] }
            unless u.nil?
                # We've already heard from them
                if consent[u][:consent] == "all" or consent[u][:consent] == "weeknotes"
                    # Save the status for inclusion in the weeknotes
                    save_toot(s, File.join(input_settings['mastodon']['publication_folder'], consent[u][:consent]))
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
                # We should save this status in a consent-pending area
                user_consent_folder = File.join(input_settings['mastodon']['consent_folder'], s['account']['acct'])
                if ensure_folder_exists(user_consent_folder)
                    save_toot(s, user_consent_folder)
                end
            end
        else
            puts "Skipping toot created at #{s['created_at']}"
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
        message = "Hi, @#{u}, we spotted your post#{toots_plural} #{toots} which we'd like to include in our weeknotes blog post.  Can we use it (and future #weeknotes posts) for all things relating to DoES Liverpool; just for our weeknotes; or not at all?  Vote or reply [All / Weeknotes / No].  We won't bother you again after this.  Thanks!"
        # Send the message to the user
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
    end

    # We'll have asked folk for consent, so update the database
    File.open(input_settings['mastodon']['consent_file'], "w") do |f|
        f.write(consent.to_yaml)
    end
end

