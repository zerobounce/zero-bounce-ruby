# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'cgi'
require 'openssl'
require 'securerandom'
require 'stringio'
require 'zlib'
require 'zerobounce/error'

# rubocop:disable Metrics/ModuleLength, Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module Zerobounce
  # The SDK's HTTP layer, on Ruby's built-in Net::HTTP (no runtime dependency).
  #
  # One request, one response: no redirects are followed, nothing is logged
  # (Net::HTTP's debug output is never switched on), and every transport
  # failure (refused, reset, timeout, TLS, a body cut short) raises
  # {ApiResponseError} with status 0 and a redacted message. An HTTP error
  # status is NOT raised here: the response comes back and the caller turns it
  # into an error.
  module HttpTransport
    OPEN_TIMEOUT = 30
    READ_TIMEOUT = 120
    WRITE_TIMEOUT = 120

    # Response headers, readable as headers[:content_type] or
    # headers['Content-Type'] (any case).
    class Headers < Hash
      def self.normalize(key)
        key.to_s.downcase.tr('-', '_').to_sym
      end

      def [](key)
        super(self.class.normalize(key))
      end

      def key?(key)
        super(self.class.normalize(key))
      end
    end

    # The parts of a response the SDK reads: #code (Integer), #body (String),
    # #headers.
    class Response
      attr_reader :code, :body, :headers

      def initialize(code, body, headers)
        @code = code
        @body = body
        @headers = headers
      end

      def to_s
        @body
      end
    end

    module_function

    # @param redact [#call] turns an error text into its redacted form
    def execute(method:, url:, query: nil, headers: {}, body: nil, redact: nil)
      redact ||= ->(text) { text }
      uri = build_uri(url, query)
      request = build_request(method, uri, headers, body)
      perform(uri, request, redact)
    rescue ApiResponseError
      raise
    rescue StandardError => e
      raise failure(e, redact), cause: nil
    end

    def failure(error, redact)
      ApiResponseError.new(
        redact.call("The request to ZeroBounce failed (#{error.class}): #{error.message}"), 0
      )
    end

    def build_uri(url, query)
      encoded = encode_query(query)
      full = url.to_s
      full += (full.include?('?') ? '&' : '?') + encoded unless encoded.empty?
      URI.parse(full)
    end

    def build_request(method, uri, headers, body)
      klass = Net::HTTP.const_get(method.to_s.capitalize)
      request = klass.new(uri.request_uri)
      # Identity: Net::HTTP would otherwise ask for gzip, decompress it and
      # drop Content-Length, so a body cut short could no longer be told from a
      # complete one.
      request['Accept-Encoding'] = 'identity'
      request['Accept'] = '*/*'
      headers.each { |name, value| request[name.to_s.tr('_', '-')] = value.to_s unless value.nil? }
      request.body = body unless body.nil?
      request
    end

    def perform(uri, request, redact)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = WRITE_TIMEOUT
      # No silent second send: Net::HTTP would otherwise re-send an idempotent
      # request (GET, PUT, DELETE) once after an EOF or reset, and a validation
      # GET is billable.
      http.max_retries = 0
      http.start do
        http.request(request) { |res| return wrap(res, redact) }
      end
    end

    def wrap(res, redact)
      headers = Headers.new
      res.each_header { |name, value| headers[Headers.normalize(name)] = value }
      raw = res.read_body.to_s.b
      check_length!(res, raw, redact)
      body = decode(res, raw, redact)
      Response.new(res.code.to_i, with_charset(body, res['content-type']), headers)
    end

    # Fewer bytes than Content-Length is a failure, status 0 (a connection
    # that closes mid-body must not read as a complete response). A list-form
    # header ("50, 50") counts as its value when every entry agrees; entries
    # that differ are a failure too.
    def check_length!(res, raw, redact)
      return if [204, 304].include?(res.code.to_i)

      lengths = res['content-length'].to_s.split(',').map(&:strip)
      return if lengths.empty? || lengths.any? { |length| !length.match?(/\A\d+\z/) }

      if lengths.uniq.size > 1
        raise ApiResponseError.new(
          redact.call("The response from ZeroBounce had conflicting Content-Length values (#{lengths.join(', ')})."), 0
        )
      end
      return unless raw.bytesize < lengths.first.to_i

      raise ApiResponseError.new(
        redact.call("The response from ZeroBounce was cut short: #{raw.bytesize} of #{lengths.first} " \
                    'bytes arrived before the connection closed.'), 0
      )
    end

    # Identity is requested, so a compressed body is unexpected; if a server
    # sends one anyway it must be a complete stream (a gzip body without its
    # trailer is a body cut short).
    def decode(res, raw, redact)
      case res['content-encoding'].to_s.downcase
      when 'gzip', 'x-gzip'
        gunzip(raw)
      when 'deflate'
        Zlib::Inflate.inflate(raw)
      else
        raw
      end
    rescue Zlib::Error
      # cause: nil, so the Zlib error (whose message can quote the raw body)
      # is not carried along.
      raise ApiResponseError.new(redact.call('The response from ZeroBounce could not be decoded.'), 0), cause: nil
    end

    def gunzip(raw)
      reader = Zlib::GzipReader.new(StringIO.new(raw))
      text = reader.read.to_s
      reader.finish # raises Zlib::GzipFile::Error unless the stream (with its trailer) was complete
      text
    end

    def with_charset(body, content_type)
      charset = content_type.to_s[/charset=["']?([\w.:-]+)/i, 1]
      encoding = begin
        charset ? Encoding.find(charset) : Encoding::UTF_8
      rescue ArgumentError
        Encoding::UTF_8
      end
      body.dup.force_encoding(encoding)
    end

    # key=value pairs, nested hashes as k[sub] and arrays as k[].
    def flatten_params(params, parent = nil)
      return [] if params.nil?

      params.flat_map do |key, value|
        name = parent ? "#{parent}[#{key}]" : key.to_s
        if value.is_a?(Hash)
          flatten_params(value, name)
        elsif value.is_a?(Array)
          value.flat_map { |item| item.is_a?(Hash) ? flatten_params(item, "#{name}[]") : [["#{name}[]", item]] }
        else
          [[name, value]]
        end
      end
    end

    def encode_query(params)
      flatten_params(params).map do |key, value|
        value.nil? ? CGI.escape(key) : "#{CGI.escape(key)}=#{CGI.escape(value.to_s)}"
      end.join('&')
    end

    # A multipart/form-data body, built here. Returns [content_type, body].
    # +file+ is { name:, filename:, content:, content_type: }.
    def multipart(fields, file)
      boundary = "----ZerobounceRubyBoundary#{SecureRandom.hex(16)}"
      body = String.new(encoding: Encoding::BINARY)
      flatten_params(fields).each do |name, value|
        body << "--#{boundary}\r\n".b
        body << "Content-Disposition: form-data; name=\"#{quote(name)}\"\r\n\r\n".b
        body << value.to_s.b << "\r\n".b
      end
      body << "--#{boundary}\r\n".b
      body << "Content-Disposition: form-data; name=\"#{quote(file[:name])}\"; " \
              "filename=\"#{quote(file[:filename])}\"\r\n".b
      body << "Content-Type: #{file[:content_type]}\r\n\r\n".b
      body << file[:content].to_s.b << "\r\n--#{boundary}--\r\n".b
      ["multipart/form-data; boundary=#{boundary}", body]
    end

    # A header parameter value: raw UTF-8, a quote as %22, CR and LF removed.
    def quote(text)
      text.to_s.delete("\r\n").gsub('"', '%22')
    end
  end
end
# rubocop:enable Metrics/ModuleLength, Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
