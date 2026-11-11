# frozen_string_literal: true

module Zerobounce
  # Checks an API key before it is sent.
  module ApiKey
    module_function

    # The key, unchanged, or an ArgumentError when it has surrounding
    # whitespace or control characters (a key read from a file with its
    # newline). Such a key would fail at the API, and the HTTP library's own
    # error could quote it unredacted.
    def check!(api_key)
      key = api_key.to_s
      if key != key.strip || key.match?(/[\u0000-\u001f\u007f]/)
        raise ArgumentError, 'api_key has surrounding whitespace or control characters'
      end

      api_key
    end
  end
end
