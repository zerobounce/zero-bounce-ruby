# frozen_string_literal: true

require 'zerobounce/api_key'

module Zerobounce
  # One API key. Package methods share Zerobounce.config; a Client does not.
  class Client
    def initialize(apikey)
      ApiKey.check!(apikey) unless apikey.nil? || apikey.to_s.strip.empty?
      @apikey = apikey
    end

    # Keeps the API key out of logs and consoles.
    def inspect
      "#<#{self.class.name} apikey=#{@apikey.nil? ? 'nil' : '[FILTERED]'}>"
    end

    def validate(email, ip_address = nil, **options)
      Zerobounce.with_api_key(@apikey) { Zerobounce.validate(email, ip_address, **options) }
    end

    def credits
      Zerobounce.with_api_key(@apikey) { Zerobounce.credits }
    end

    def validate_batch(emails, ip_addresses = [], **options)
      Zerobounce.with_api_key(@apikey) { Zerobounce.validate_batch(emails, ip_addresses, **options) }
    end
  end
end
