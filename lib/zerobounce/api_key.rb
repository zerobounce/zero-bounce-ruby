# frozen_string_literal: true

require 'erb'
require 'json'
require 'uri'

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

    # Every form a secret can take in a body or URL echoed back to us: raw,
    # URL-encoded (%20 and + styles), JSON-escaped (with and without "\/",
    # non-ASCII as is or as \uXXXX) and the URL-encoded JSON form (a server
    # echoing a URL-encoded copy of a JSON request body). Longest first, so a
    # form that contains another is masked whole.
    def secret_forms(secret)
      raw = secret.to_s
      return [] if raw.empty?

      json = JSON.generate(raw)[1..-2]
      forms = url_forms(raw) + json_forms(raw) + url_forms(json).drop(1)
      forms.uniq.reject(&:empty?).sort_by { |form| -form.length }
    end

    def url_forms(raw)
      [raw, ERB::Util.url_encode(raw), URI.encode_www_form_component(raw)]
    end

    def json_forms(raw)
      [raw.inspect[1..-2], JSON.generate(raw)[1..-2], JSON.generate(raw, ascii_only: true)[1..-2],
       slash_escaped_json(raw), slash_escaped_json(raw, ascii_only: true)]
    end

    # The JSON string body with "/" written "\/", as some servers do. Built
    # one character at a time with the JSON generator, so a backslash or quote
    # in the secret is escaped exactly as JSON escapes it. (JSON's script_safe
    # option does this too, but only from json 2.7; Ruby 3.0 to 3.2 ship older
    # versions that ignore it.)
    def slash_escaped_json(raw, **options)
      raw.each_char.map { |char| char == '/' ? '\/' : JSON.generate(char, **options)[1..-2] }.join
    end

    # The text with every form of every secret replaced by ***.
    def redact(text, secrets)
      value = text.to_s
      secrets.each do |secret|
        next if secret.nil? || secret.to_s.strip.empty?

        secret_forms(secret).each { |form| value = value.gsub(form, '***') }
      end
      value
    end

    # Refuses Marshal and YAML serialisation of an object that holds an API
    # key: the dump would carry the key to wherever it is written.
    module RefusesDump
      def marshal_dump
        raise TypeError, "#{self.class.name} cannot be serialised: it holds an API key"
      end

      def _dump(_level)
        marshal_dump
      end

      def encode_with(_coder)
        marshal_dump
      end
    end
  end
end
