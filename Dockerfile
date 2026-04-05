# ZeroBounce Ruby SDK – test image (Ruby 3.2)
FROM ruby:3.2-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

COPY . .
# Gemfile.lock expects Bundler 2.4.x (see gemspec); Ruby 3.2 image may ship Bundler 4.x.
RUN gem install bundler -v 2.4.22 && \
    bundle config set --local path 'vendor/bundle' && \
    bundle _2.4.22_ install

# Dummy key for VCR/cassette-based specs; override with env for live API
ENV ZEROBOUNCE_API_KEY="${ZEROBOUNCE_API_KEY:-invalid_key_for_tests}"

CMD ["bundle", "_2.4.22_", "exec", "rspec"]
