weeknote-generator
==================

Collects reports of #weeknotes and collates them into a blog post

## Development

Not a complete set of instructions, needs fleshing out more...

1. Run `bundle install`
1. Create a YAML file for the config

Then there are three main operations:

* `bundle exec ruby find_toots.rb` to find relevant posts on Mastodon and ask for consent if needed
* `bundle exec ruby check_consent_requests.rb` to check for responses to consent requests

Those two should be run regularly to gather the data needed by the third script:

* `bundle exec ruby generate_weeknotes.rb NAME-OF-CONFIG-FILE.yaml`

which is run once-a-week to create the weeknotes post.

## Deployment

We run the code under `Docker` when deployed.

1. Clone the repo
1. Generate the `Gemfile.lock` file: `docker run --rm -v "$PWD":/usr/src/app -w /usr/src/app ruby:3.1 bundle install`
1. Build the image `docker build -t weeknotes .`
1. Set up webserver to serve the static files.  The docker setup expects this to be available as a volume mounted at `/var/local/media_root`
1. Create a folder to hold the work files (list of who has given consent, toots ready to publish, etc.).  The docker setup expects this to be available as a volume mounted at `/var/local/workfiles`
1. Create the config YAML file called `weeknotes-config.yaml`.  This should live in the folder used to contain the work files (docker expects to find it at `/var/local/workfiles/weeknotes-config.yaml`)
1. Set up cron to run:
   * `docker run [add volume arguments] weeknotes [operation]`

## Manually Adding Toots

If you need to pull in a Mastodon post that hasn't been picked up automatically (e.g. if it was posted as `unlisted` or you forgot the `#weeknotes` tag) then you can download them manually.

1. Get the status ID from the post in the web interface.  It's the long number at the end of the URL for it.  NB: I'm not sure what the case would be for posts made on other servers, which are then federated!
1. Run `curl -H 'Authorization: Bearer INSERT-BEARER-TOKEN-HERE' https://MASTODON-SERVER/api/v1/statuses/STATUS-ID > mastodon-ready-to-publish/all/STATUS-ID.json`

That will store the JSON version of the post in the right place for the `generate-weeknotes.rb` script to pick it up next time it generates the weeknotes.
