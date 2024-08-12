FROM ruby:3.1

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

# Create the volume mount points
RUN mkdir /var/local/media_root
RUN mkdir /var/local/workfiles
VOLUME /var/local/media_root /var/local/workfiles

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# This script will kick off the relevant operation
# It should be a script to allow one of the three operations, which can
# then be passed in as arguments to docker, e.g. `docker run weeknotes check-consent`
ENTRYPOINT ["./docker-entrypoint.sh"]
