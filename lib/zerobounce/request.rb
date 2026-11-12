# frozen_string_literal: true

require 'zerobounce/base_request'
require 'zerobounce/get_file_helper'

module Zerobounce

  # Sends the HTTP request.
  class Request < BaseRequest

    # The email finder and domain search. Their result is never a bare
    # message, so a body made only of message keys is how they report a
    # rejected request. LIVE: an invalid or drained key gets an HTTP 200 with
    # {"Message": "Invalid API key or your account ran out of credits"}.
    # Everywhere else a bare message is a result: validate's greylist answer
    # {"Message": "Greylist validation still in progress..."} and the
    # filters' {"Message": "Filter successfully added"}.
    MESSAGE_ONLY_ERROR_PATHS = %w[guessformat].freeze

    def self.get(path, params, content_type='application/json')
      response = self._get(Zerobounce.configuration.api_root_url, path, params, content_type)
      interpret_json_response(response, path)
    end

    def self.bulk_get(path, params, content_type='application/json')
      response = self._get(Zerobounce.configuration.bulk_api_root_url, path, params, content_type)
      if __json_content_type__(response.headers[:content_type])
        response_body_json = __parse_json_body__(response)
        return __require_shape__(response, response_body_json, path) unless response_body_json.is_a?(Hash)

        if __error_value__(response_body_json['error'])
          raise ApiResponseError.new(ResponseError.strip_prefix(response_body_json['error']), response.code)
        end
        if response_body_json['errors'].is_a?(Array) && !response_body_json['errors'].empty?
          raise ApiResponseError.new(__first_error__(response, response_body_json['errors']).to_s, response.code)
        end
        __raise_if_success_false__(response, response_body_json)
        __raise_if_bare_error__(response, response_body_json)

        return __require_shape__(response, response_body_json, path)
      else
        # filestatus and deletefile answer in JSON: anything else (an HTML
        # page, an empty or non-JSON body) raises with the HTTP status.
        __parse_json_response__(response, path)
      end
    end

    # Bulk getfile only: treats non-2xx and JSON error payloads (including HTTP 200) as failures.
    def self.bulk_getfile(path, params)
      response = self._get(Zerobounce.configuration.bulk_api_root_url, path, params, 'application/json')
      GetFileHelper.process_getfile_response(response)
    end

    def self.post(path, params, content_type='application/json', filepath=nil)
      response = self._post(Zerobounce.configuration.api_root_url, path, params, \
          content_type, filepath)
      interpret_json_response(response, path)
    end

    # +root+ defaults to bulk_api_root_url; the list evaluator passes its own.
    def self.bulk_post(path, params, content_type='application/json', filepath=nil,
                       root: Zerobounce.configuration.bulk_api_root_url)
      response = self._post(root, path, params, content_type, filepath)
      __parse_json_response__(response)
    end

    def self.bulk_root_get(path, params, content_type='application/json')
      response = self._get(bulk_api_root_without_v2, path, params, content_type)
      __parse_json_response__(response, path)
    end

    def self.bulk_root_getfile(path, params)
      response = self._get(bulk_api_root_without_v2, path, params, 'application/json')
      GetFileHelper.process_getfile_response(response)
    end

    def self.bulk_root_post(path, params, content_type='application/json', filepath=nil)
      response = self._post(bulk_api_root_without_v2, path, params, content_type, filepath)
      __parse_json_response__(response)
    end

    def self.bulk_root_form_post(path, params)
      response = self._post(bulk_api_root_without_v2, path, params, 'application/x-www-form-urlencoded')
      __parse_json_response__(response)
    end

    def self.interpret_json_response(response, path = nil)
      body = response.body.to_s
      content_type = (response.headers[:content_type] || '').to_s
      if ResponseError.html?(body, content_type) || body.strip.empty? ||
         (!content_type.include?('json') && !body.strip.start_with?('{', '['))
        raise ApiResponseError.new(ResponseError.message_from_parts(response.code, content_type, body), response.code)
      end
      begin
        parsed = StrictJson.parse(body)
      rescue JSON::ParserError
        # cause: nil, or the parser's error, which quotes the body, would ride
        # along as #cause.
        raise ApiResponseError.new('ZeroBounce returned a response that is not valid JSON.', response.code),
              cause: nil
      end
      return __require_shape__(response, parsed, path) unless parsed.is_a?(Hash)

      code = response.code
      if __error_value__(parsed['error'])
        raise ApiResponseError.new(ResponseError.strip_prefix(parsed['error']), code)
      end
      __raise_if_success_false__(response, parsed)
      __raise_if_bare_error__(response, parsed)
      __raise_if_message_only__(response, parsed) if MESSAGE_ONLY_ERROR_PATHS.include?(path)
      if parsed.key?('errors') && parsed['errors'].is_a?(Array) && !parsed['errors'].empty?
        account = parsed['errors'].find { |item| item.is_a?(Hash) && item['email_address'].to_s.casecmp('all').zero? }
        if account
          raise ApiResponseError.new(ResponseError.strip_prefix(account['error']), code)
        end
        unless path == 'validatebatch'
          raise ApiResponseError.new(ResponseError.strip_prefix(__first_error__(response, parsed['errors'])), code)
        end
      end
      __require_shape__(response, parsed, path)
    end

  end

end
