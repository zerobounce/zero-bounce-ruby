# ZeroBounce Ruby SDK – test image (Ruby 3.4, as in the SDK CI matrix)
FROM ruby:3.4-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

COPY . .
# Gemfile.lock is BUNDLED WITH 2.4.22 (gemspec: bundler ~> 2.4.6); the Ruby 3.4 image ships a newer Bundler.
RUN gem install bundler -v 2.4.22 && \
    bundle config set --local path 'vendor/bundle' && \
    bundle _2.4.22_ install

# Dummy key for VCR/cassette-based specs; override with env for live API
ENV ZEROBOUNCE_API_KEY="${ZEROBOUNCE_API_KEY:-invalid_key_for_tests}"

# The specs write fixture files, .rspec_status and coverage/ under /app, so the
# non-root test user owns it.
RUN chown -R 65532:65532 /app

USER 65532:65532

CMD ["bundle", "_2.4.22_", "exec", "rspec"]
