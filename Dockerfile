# ZeroBounce Ruby SDK – test image (Ruby 3.2)
FROM ruby:3.2-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

COPY . .
RUN bundle config set --local path 'vendor/bundle' && \
    bundle install

# Dummy key for VCR/cassette-based specs; override with env for live API
ENV ZEROBOUNCE_API_KEY="${ZEROBOUNCE_API_KEY:-invalid_key_for_tests}"

CMD ["bundle", "exec", "rspec"]
