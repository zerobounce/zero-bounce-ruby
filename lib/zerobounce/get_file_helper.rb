# frozen_string_literal: true

require 'json'
require 'stringio'
require 'zerobounce/error'
require 'zerobounce/response_error'

module Zerobounce
  # Bulk getfile response handling (v2): HTTP errors, JSON error bodies (including HTTP 200).
  module GetFileHelper
    module_function

    BOM = "\uFEFF"

    # The text without a leading byte-order mark (a UTF-8 BOM, however the
    # body was decoded).
    # @param [String] body
    # @return [String]
    def strip_bom(body)
      text = body.to_s.dup
      text.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::BINARY
      text = text.scrub('') unless text.valid_encoding?
      text.delete_prefix(BOM)
    end

    # Whether the Content-Type is JSON: application/json, any */*+json
    # (application/problem+json), or application/json anywhere in the value.
    # @param [String] content_type
    # @return [Boolean]
    def json_type?(content_type)
      value = content_type.to_s.downcase
      media = value.split(';').first.to_s.strip
      media == 'application/json' || media.end_with?('+json') || value.include?('application/json')
    end

    # Whether the body (after a BOM and white space) is a JSON object or array.
    # No result file is one, so it is an API answer, not file content.
    # @param [String] body
    # @return [Boolean]
    def json_container?(body)
      text = strip_bom(body).lstrip
      return false unless text.start_with?('{', '[')

      JSON.parse(text)
      true
    rescue JSON::ParserError
      false
    end

    # @param [String] body
    # @return [Boolean]
    def json_indicates_error?(body)
      json_container?(body)
    end

    # @param [String] body
    # @return [String]
    def format_error_message(body)
      o = JSON.parse(strip_bom(body))
      return body.to_s unless o.is_a?(Hash)

      %w[message error error_message].each do |k|
        v = o[k]
        next if v.nil?
        return v.strip if v.is_a?(String) && !v.strip.empty?
        return v[0].strip if v.is_a?(Array) && v[0].is_a?(String)
      end
      body.to_s
    rescue JSON::ParserError
      body.to_s.empty? ? 'Invalid getfile response' : body.to_s
    end

    # @param [String] body
    # @param [String] content_type
    # @return [Boolean]
    def should_treat_as_error?(body, content_type)
      json_type?(content_type) || json_container?(body)
    end

    # @param [Zerobounce::HttpTransport::Response] response
    # @return [String] CSV/text body on success
    def process_getfile_response(response)
      code = response.code.to_i
      body_str = response.body.to_s
      ct = (response.headers[:content_type] || response.headers['Content-Type'] || '').to_s

      # An empty body is no result file: an error, as in the other SDKs.
      if code > 299 || strip_bom(body_str).strip.empty? || ResponseError.html?(body_str, ct)
        raise ApiResponseError.new(ResponseError.message_from_parts(code, ct, body_str), code)
      end

      if should_treat_as_error?(body_str, ct)
        raise ApiResponseError.new(ResponseError.message_from_parts(code, ct, strip_bom(body_str)), code)
      end

      io = StringIO.new(response.body)
      io.set_encoding_by_bom
      io.string
    end
  end
end
