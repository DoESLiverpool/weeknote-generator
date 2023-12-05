require 'rubygems'
require 'json'
require 'yaml'
require 'sanitize'
require 'open-uri'
require 'rest-client'

# This URL gets (when the ID is inserted) details of the vote
status_url_tamplate = 'https://does.social/api/v1/statuses/%s'
# This URL gets (when the ID is inserted) details of any replies
status_context_url_tamplate = 'https://does.social/api/v1/statuses/%s/context'
# This URL lets us post toots
post_status_url = "https://does.social/api/v1/statuses"

# Send a message to @amcewen to alert him to an error
def toot_error(message)
    payload = { status: "@amcewen@mastodon.me.uk #{message}", visibility: "direct" }
    resp = RestClient.post(post_status_url, payload, { "Authorization": "Bearer #{bearer_token}"})
end

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
    if u[:consent].nil?
        unless u[:consent_request].nil?
            # Do we need to reply?  Default to no
            thanks_reply = nil

            status_url = status_url_tamplate % u[:consent_request]
            status_info = JSON.parse(URI.open(status_url, "Authorization" => "Bearer #{bearer_token}").read)
            #pp status_info
            # Check for poll responses
            if status_info["poll"]["votes_count"] > 1
                toot_error("Check #{u[:consent_request]} - too many votes: #{status_info['poll']['votes_count']}")
            elsif status_info["poll"]["votes_count"] > 0
                puts "Voted upon!"
                status_info["poll"]["options"].each do |v|
                    if v["votes_count"] > 0
                        # Tweak it to get rid of the "just" in "just weeknotes"
                        u[:consent] = v["title"].split(" ")[-1]
                    end
                end
                # Reply to the original poll post, if we don't find a reply
                thanks_reply = { "in_reply_to_id": status_info["id"], "in_reply_to_account_id": status_info["account"]["id"] }
            end

            if u[:consent].nil?
                # There wasn't a vote, look for a reply
                status_context_url = status_context_url_tamplate % u[:consent_request]
                status_context = JSON.parse(URI.open(status_context_url, "Authorization" => "Bearer #{bearer_token}").read)
                #pp status_context

                # Search for any children with responses
                status_context['descendants'].each do |d|
                    if d['account']['acct'] == status_info['mentions'][0]['acct']
                        # It's a reply from the account we asked
                        # Strip out any unwanted HTML to just get the text
                        reply = Sanitize.fragment(d['content'], Sanitize::Config::RESTRICTED)
                        #puts reply
                        if reply.include?("no")
                            u[:consent] = "no"
                            u[:consent_link] = d['url']
                            thanks_reply = { "in_reply_to_id": d["id"], "in_reply_to_account_id": d["account"]["id"] }
                        elsif reply.include?("weeknotes")
                            u[:consent] = "weeknotes"
                            u[:consent_link] = d['url']
                            thanks_reply = { "in_reply_to_id": d["id"], "in_reply_to_account_id": d["account"]["id"] }
                        elsif reply.include?("all")
                            u[:consent] = "all"
                            u[:consent_link] = d['url']
                            thanks_reply = { "in_reply_to_id": d["id"], "in_reply_to_account_id": d["account"]["id"] }
                        else
                            toot_error("unexpected reply with content >>#{reply}<<")
                        end
                    end
                end
            end

            unless thanks_reply.nil?
                # we've had a reply
                message = "@#{u[:user]} Thanks for getting back to us!"
                # Send the message to the user
# FIXME For now just spam me :-)
if u[:user] == "amcewen@mastodon.me.uk"
                puts "Spamming #{u} => #{message}"
                thanks_reply["status"] = message
                thanks_reply["visibility"] = "direct"
                resp = RestClient.post(post_status_url, thanks_reply, { "Authorization": "Bearer #{bearer_token}"})
                if resp.code == 200
                else
                    toot_error("Error sending consent request to #{u}: #{message}")
                    puts "Error sending consent request to #{u}: #{message}"
                    puts resp.code
                    puts resp.body
                end
else
                puts "#{u} => #{message}"
end
                # Now process any pending messages from that user!
                user_consent_folder = File.join(input_settings['mastodon']['consent_folder'], u[:user])
                if u[:consent] == "all" or u[:consent] == "weeknotes"
                    # Move the toots to be published
                    FileUtils.mv Dir.glob(File.join(user_consent_folder, "*")), File.join(input_settings['mastodon']['publication_folder'], u[:consent])
                end
                # Remove the user's pending consent folder (and any remaining
                # toots if consent wasn't granted)
                FileUtils.rm_rf user_consent_folder
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

