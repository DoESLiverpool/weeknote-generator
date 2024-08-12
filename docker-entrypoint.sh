#!/bin/bash
# Script called as the entry point for the docker container

CONFIG_FILE="/var/local/workfiles/weeknotes-config.yaml"

if [[ $1 == "check-consent" ]]; then
    echo "bundle exec ruby check_consent_requests.rb"
    bundle exec ruby check_consent_requests.rb $CONFIG_FILE
elif [[ $1 == "find-toots" ]]; then
    echo "bundle exec ruby find_toots.rb $CONFIG_FILE"
    bundle exec ruby find_toots.rb $CONFIG_FILE
elif [[ $1 == "generate-weeknotes" ]]; then
    echo "bundle exec ruby generate_weeknotes.rb"
    bundle exec ruby generate_weeknotes.rb $CONFIG_FILE
else
    echo "Usage:"
    echo "  docker-entrypoint.sh <command>"
    echo "where command is one of:"
    echo "  check-consent"
    echo "  find-toots"
    echo "  generate-weeknotes"
fi
