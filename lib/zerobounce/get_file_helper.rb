# frozen_string_literal: true

require 'json'
require 'stringio'

module Zerobounce
  # Bulk getfile response handling (v2): HTTP errors, JSON error bodies (including HTTP 200).
  module GetFileHelper
    module_function

    # @param [String] body
    # @return [Boolean]
    def json_indicates_error?(body)
      t = body.to_s.lstrip
      return false if t.empty? || t[0] != '{'

      o = JSON.parse(t)
      return false unless o.is_a?(Hash)

      if o.key?('success')
        s = o['success']
        return true if s == false || s == 'False' || s == 'false'
      end

      %w[message error error_message].each do |k|
        v = o[k]
        next if v.nil?

        return true if v.is_a?(String) && !v.strip.empty?
        return true if v.is_a?(Array) && !v.empty?
      end

      o.key?('success')
    rescue JSON::ParserError
      false
    end

    # @param [String] body
    # @return [String]
    def format_error_message(body)
      o = JSON.parse(body.to_s)
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
      ct = content_type.to_s.downcase
      return true if ct.include?('application/json')

      json_indicates_error?(body)
    end

    # @param [RestClient::Response] response
    # @return [String] CSV/text body on success
    def process_getfile_response(response)
      code = response.code.to_i
      body_str = response.body.to_s
      ct = (response.headers[:content_type] || response.headers['Content-Type'] || '').to_s

      if code > 299
        msg = if body_str.lstrip.start_with?('{')
                format_error_message(body_str)
              else
                body_str.empty? ? "HTTP #{code}" : body_str
              end
        raise msg
      end

      if should_treat_as_error?(body_str, ct)
        raise format_error_message(body_str)
      end

      io = StringIO.new(response.body)
      io.set_encoding_by_bom
      io.string
    end
  end
end
