# frozen_string_literal: true

require 'json'

module Zerobounce
  # Parses a response body as strict RFC 8259 JSON.
  #
  # Ruby's JSON.parse is lenient: it accepts /* */ and // comments (json 2.7
  # and later), and other versions differ in what else they let through. A
  # body that is not JSON is not an API response, so the body is checked
  # first, untrimmed, by a small RFC 8259 validator: only space, tab, CR and
  # LF may surround the value (no BOM, no NBSP, no NUL). Only then is it
  # parsed, with allow_nan: false pinned.
  #
  # A recursive-descent validator reads best as one method per grammar rule,
  # so the method size metrics are off for this module.
  # rubocop:disable Metrics/ModuleLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  module StrictJson
    module_function

    WHITESPACE = [0x20, 0x09, 0x0a, 0x0d].freeze
    ESCAPES = '"\\/bfnrt'.bytes.freeze
    HEX = '0123456789abcdefABCDEF'.bytes.freeze
    MAX_DEPTH = 512

    # The parsed value, or JSON::ParserError (without the body in its message).
    def parse(text)
      body = text.to_s
      raise JSON::ParserError, 'response is not valid JSON' unless valid?(body)

      JSON.parse(body, allow_nan: false)
    end

    # Whether the whole text is one RFC 8259 JSON value.
    def valid?(text)
      bytes = text.to_s.b
      pos = value(bytes, skip_ws(bytes, 0), 0)
      !pos.nil? && skip_ws(bytes, pos) == bytes.bytesize
    end

    def skip_ws(bytes, pos)
      pos += 1 while pos < bytes.bytesize && WHITESPACE.include?(bytes.getbyte(pos))
      pos
    end

    # The position after the value at pos, or nil.
    def value(bytes, pos, depth)
      return nil if depth > MAX_DEPTH

      case bytes.getbyte(pos)
      when 0x7b then object(bytes, pos + 1, depth + 1)
      when 0x5b then array(bytes, pos + 1, depth + 1)
      when 0x22 then string(bytes, pos + 1)
      when 0x74 then literal(bytes, pos, 'true')
      when 0x66 then literal(bytes, pos, 'false')
      when 0x6e then literal(bytes, pos, 'null')
      else number(bytes, pos)
      end
    end

    def literal(bytes, pos, word)
      bytes.byteslice(pos, word.bytesize) == word ? pos + word.bytesize : nil
    end

    def object(bytes, pos, depth)
      pos = skip_ws(bytes, pos)
      return pos + 1 if bytes.getbyte(pos) == 0x7d

      loop do
        return nil unless bytes.getbyte(pos) == 0x22

        pos = string(bytes, pos + 1)
        return nil if pos.nil?

        pos = skip_ws(bytes, pos)
        return nil unless bytes.getbyte(pos) == 0x3a

        pos = value(bytes, skip_ws(bytes, pos + 1), depth)
        return nil if pos.nil?

        pos = skip_ws(bytes, pos)
        case bytes.getbyte(pos)
        when 0x7d then return pos + 1
        when 0x2c then pos = skip_ws(bytes, pos + 1)
        else return nil
        end
      end
    end

    def array(bytes, pos, depth)
      pos = skip_ws(bytes, pos)
      return pos + 1 if bytes.getbyte(pos) == 0x5d

      loop do
        pos = value(bytes, pos, depth)
        return nil if pos.nil?

        pos = skip_ws(bytes, pos)
        case bytes.getbyte(pos)
        when 0x5d then return pos + 1
        when 0x2c then pos = skip_ws(bytes, pos + 1)
        else return nil
        end
      end
    end

    # pos is just after the opening quote.
    def string(bytes, pos)
      loop do
        byte = bytes.getbyte(pos)
        return nil if byte.nil? || byte < 0x20
        return pos + 1 if byte == 0x22

        if byte == 0x5c
          escape = bytes.getbyte(pos + 1)
          if escape == 0x75
            return nil unless (2..5).all? { |i| HEX.include?(bytes.getbyte(pos + i)) }

            pos += 6
          elsif ESCAPES.include?(escape)
            pos += 2
          else
            return nil
          end
        else
          pos += 1
        end
      end
    end

    # -? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?
    def number(bytes, pos)
      pos += 1 if bytes.getbyte(pos) == 0x2d
      first = bytes.getbyte(pos)
      return nil unless digit?(first)

      pos = first == 0x30 ? pos + 1 : digits(bytes, pos)
      if bytes.getbyte(pos) == 0x2e
        return nil unless digit?(bytes.getbyte(pos + 1))

        pos = digits(bytes, pos + 1)
      end
      if [0x65, 0x45].include?(bytes.getbyte(pos))
        pos += 1
        pos += 1 if [0x2b, 0x2d].include?(bytes.getbyte(pos))
        return nil unless digit?(bytes.getbyte(pos))

        pos = digits(bytes, pos)
      end
      pos
    end

    def digits(bytes, pos)
      pos += 1 while digit?(bytes.getbyte(pos))
      pos
    end

    def digit?(byte)
      !byte.nil? && byte >= 0x30 && byte <= 0x39
    end
  end
  # rubocop:enable Metrics/ModuleLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
end
