# frozen_string_literal: true

module Zerobounce
  # A boolean option, parsed strictly: true/false, 'true'/'false' in any case,
  # or 1/0. Anything else is an ArgumentError, so 'false' can no longer be sent
  # as true and a typo is not silently taken as a flag. Shared by the client
  # and the Warmup client.
  module StrictBool
    module_function

    def parse(value, name)
      return value if [true, false].include?(value)
      return value == 1 if value.is_a?(Integer) && [0, 1].include?(value)

      if value.is_a?(String)
        text = value.strip.downcase
        return true if %w[true 1].include?(text)
        return false if %w[false 0].include?(text)
      end
      raise ArgumentError, "#{name} must be true or false"
    end
  end
end
