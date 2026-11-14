# frozen_string_literal: true

require 'erb'
require 'json'
require 'uri'

module Zerobounce
  # Checks an API key before it is sent.
  module ApiKey # rubocop:disable Metrics/ModuleLength
    module_function

    CHARACTERS_PROBLEM = 'api_key has whitespace, control or invisible characters'
    HEADER_PROBLEM = 'api_key has characters that cannot be sent in an HTTP header'
    UNSAFE_CHARACTERS = /[[:space:][:cntrl:]\p{Cf}\p{Zs}\p{Zl}\p{Zp}\u180e]/

    # The key, unchanged, or an ArgumentError when it holds whitespace of any
    # kind (NBSP, U+0085, U+2028, U+3000), control or Unicode format characters
    # (U+200B, U+FEFF, U+180E) anywhere, or anything outside printable ASCII
    # (a key read from a file with its newline, or pasted with an invisible
    # character). Such a key would fail at the API, and the HTTP library's own
    # error could quote it unredacted.
    def check!(api_key)
      key = api_key.to_s
      raise ArgumentError, HEADER_PROBLEM unless key.valid_encoding?
      raise ArgumentError, CHARACTERS_PROBLEM if key.match?(UNSAFE_CHARACTERS)
      raise ArgumentError, HEADER_PROBLEM if key.match?(/[^\x21-\x7e]/)

      api_key
    end

    # Every form a secret can take in a body or URL echoed back to us,
    # composed from the encoders up to depth 2: {raw, JSON-escaped,
    # JSON-escaped with "\/"} (each JSON form with non-ASCII as is or as
    # \uXXXX) x {as is, URL-encoded with %20, URL-encoded with +}, each JSON
    # form escaped twice (a JSON error body quoting the JSON request body),
    # and #inspect. Longest first, so a form that contains another is masked
    # whole.
    def secret_forms(secret)
      raw = secret.to_s
      return [] if raw.empty?

      forms = escaped_forms(raw).flat_map { |form| url_forms(form) } + twice_escaped(raw) + [raw.inspect[1..-2]]
      forms.uniq.reject(&:empty?).sort_by { |form| -form.length }
    end

    def escaped_forms(raw)
      [raw] + json_escapers.map { |escape| escape.call(raw) }
    end

    def twice_escaped(raw)
      json_escapers.map { |escape| escape.call(escape.call(raw)) }
    end

    def url_forms(raw)
      [raw, ERB::Util.url_encode(raw), URI.encode_www_form_component(raw)]
    end

    # Text as it appears inside a JSON string: non-ASCII as is or as \uXXXX,
    # "/" as is or as "\/".
    def json_escapers
      [->(text) { JSON.generate(text)[1..-2] },
       ->(text) { JSON.generate(text, ascii_only: true)[1..-2] },
       ->(text) { slash_escaped_json(text) },
       ->(text) { slash_escaped_json(text, ascii_only: true) }]
    end

    # The JSON string body with "/" written "\/", as some servers do. Built
    # one character at a time with the JSON generator, so a backslash or quote
    # in the secret is escaped exactly as JSON escapes it. (JSON's script_safe
    # option does this too, but only from json 2.7; Ruby 3.0 to 3.2 ship older
    # versions that ignore it.)
    def slash_escaped_json(raw, **options)
      raw.each_char.map { |char| char == '/' ? '\/' : JSON.generate(char, **options)[1..-2] }.join
    end

    # What an error says instead of text that still holds a secret in an
    # encoding no spelling covers.
    CREDENTIAL_OMITTED_MESSAGE =
      'ZeroBounce returned an error; the response body was omitted because it contained a credential.'

    # A secret shorter than this is masked only as a whole token (not touching
    # a letter or digit), so a one-character password does not turn "Failed to
    # open" into "Failed to o***en". From this length a secret is masked
    # wherever it occurs; a password of 8 characters or more never appears in
    # an ordinary word by chance.
    WHOLE_TOKEN_BELOW = 8

    # The text with every form of every secret replaced by ***, whatever the
    # letter case. Then closed under encoding: if any decoded view of what is
    # left (URL-decoding, "+" as a space, JSON unescaping incl. "\/" and
    # \uXXXX, HTML entities, "\'" and "\"", up to four layers in any order)
    # still holds a secret, the whole text is replaced by
    # CREDENTIAL_OMITTED_MESSAGE.
    def redact(text, secrets)
      value = text.to_s.b
      secrets = secrets.compact.map(&:to_s).reject { |secret| secret.strip.empty? }
      secrets.each { |secret| value = value.gsub(secret_pattern(secret_forms(secret), secret), '***'.b) }
      value = value.force_encoding(Encoding::UTF_8).scrub
      return CREDENTIAL_OMITTED_MESSAGE if holds_secret?(value, secrets)

      value
    end

    # One case-insensitive pattern over the forms (bytes, so it also matches
    # text that is not valid UTF-8); a short secret must stand as a whole token.
    def secret_pattern(forms, secret)
      body = forms.map { |form| Regexp.escape(form.b) }.join('|')
      body = "(?<![A-Za-z0-9])(?:#{body})(?![A-Za-z0-9])" if secret.length < WHOLE_TOKEN_BELOW
      Regexp.new(body.b, Regexp::IGNORECASE)
    end

    # Whether any decoded view of the text contains one of the secrets, in any
    # letter case. Compared as bytes, so text that decodes to invalid UTF-8 is
    # still checked.
    def holds_secret?(text, secrets)
      return false if secrets.empty?

      views = decoded_views(text)
      patterns = secrets.map { |secret| secret_pattern([secret], secret) }
      patterns.any? { |pattern| views.any? { |view| view.match?(pattern) } }
    end

    # How many layers of encoding the check undoes: the SDK's own request
    # encoding plus three echo layers (standard.md).
    DECODE_LAYERS = 4

    # The text (as bytes) and every view of it after up to DECODE_LAYERS decodings.
    def decoded_views(text, layers = DECODE_LAYERS)
      views = [text.to_s.b]
      frontier = views
      layers.times do
        frontier = frontier.flat_map { |view| DECODERS.map { |decode| decode.call(view) } }.uniq - views
        break if frontier.empty?

        views += frontier
      end
      views
    end

    def url_decode(bytes)
      bytes.gsub(/%([0-9A-Fa-f]{2})/n) { Regexp.last_match(1).hex.chr }
    end

    SURROGATE_PAIR = /\\u(d[89ab][0-9a-f]{2})\\u(d[c-f][0-9a-f]{2})/ni
    JSON_ESCAPE = %r{\\(?:u([0-9a-fA-F]{4})|(["\\/bfnrt]))}n
    SIMPLE_ESCAPES = { '"' => '"', '\\' => '\\', '/' => '/', 'b' => "\b", 'f' => "\f", 'n' => "\n",
                       'r' => "\r", 't' => "\t" }.freeze

    def json_unescape(bytes) # rubocop:disable Metrics/AbcSize
      paired = bytes.gsub(SURROGATE_PAIR) do
        high = Regexp.last_match(1).hex
        low = Regexp.last_match(2).hex
        [0x10000 + ((high - 0xd800) << 10) + (low - 0xdc00)].pack('U').b
      end
      paired.gsub(JSON_ESCAPE) do
        code = Regexp.last_match(1)
        code ? [code.hex].pack('U').b : SIMPLE_ESCAPES.fetch(Regexp.last_match(2)).b
      end
    end

    HTML_ENTITY = /&(?:#(\d{1,7});?|#[xX]([0-9a-fA-F]{1,6});?|(amp|lt|gt|quot|apos);)/n
    NAMED_ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'" }.freeze

    # HTML entities decoded: &#100; &#x64; &#39; &quot; &amp; ...
    def html_unescape(bytes) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      bytes.gsub(HTML_ENTITY) do
        match = Regexp.last_match
        code = match[1]&.to_i || match[2]&.hex
        if code.nil?
          NAMED_ENTITIES.fetch(match[3]).b
        elsif code.positive? && code <= 0x10FFFF && !code.between?(0xD800, 0xDFFF)
          [code].pack('U').b
        else
          match[0]
        end
      end
    end

    def unescape_quotes(bytes)
      bytes.gsub(/\\(['"])/n, '\1')
    end

    DECODERS = [
      ->(bytes) { url_decode(bytes) },
      ->(bytes) { url_decode(bytes.tr('+', ' ')) },
      ->(bytes) { bytes.tr('+', ' ') },
      ->(bytes) { json_unescape(bytes) },
      ->(bytes) { html_unescape(bytes) },
      ->(bytes) { unescape_quotes(bytes) }
    ].freeze

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

    # The key a client holds. Its text is masked, so a dump of the client's
    # instance variables (instance_variables, instance_variable_get, pp) shows
    # [FILTERED] rather than the key. Read the key with #value.
    class Secret
      include RefusesDump

      attr_reader :value

      def initialize(value)
        @value = value
      end

      def inspect
        '[FILTERED]'
      end
      alias to_s inspect
    end
  end
end
