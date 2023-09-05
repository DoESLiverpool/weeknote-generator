require 'rubygems'
require 'json'
require 'yaml'
require 'open-uri'
require 'rest-client'

# This URL gets (when the ID is inserted) details of the vote
status_url_tamplate = 'https://does.social/api/v1/statuses/%s'
# This URL gets (when the ID is inserted) details of any replies
status_context_url_tamplate = 'https://does.social/api/v1/statuses/%s/context'

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

consent.each do |u|
    puts u
    if u['consent_response'].nil?
        unless u[:consent_request].nil?
            status_url = status_url_tamplate % u[:consent_request]
            status_context = JSON.parse(URI.open(status_url, "Authorization" => "Bearer #{bearer_token}").read)
            puts status_context
            if false # we've had a reply
                message = "Thanks for getting back to us!"
                # Send the message to the user
                # FIXME This should be a reply to their reply
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
        else
            puts "Strange consent entry: #{u}"
        end
    # else we've already had a reply to our request
    end
end


# Save any updates to the database
File.open(input_settings['mastodon']['consent_file'], "w") do |f|
    f.write(consent.to_yaml)
end

