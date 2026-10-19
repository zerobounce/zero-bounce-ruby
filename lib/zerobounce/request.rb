# frozen_string_literal: true

require 'stringio'
require 'zerobounce/base_request'
require 'zerobounce/get_file_helper'

module Zerobounce

  # Sends the HTTP request.
  class Request < BaseRequest

    def self.get(path, params, content_type='application/json')
      response = self._get(Zerobounce.configuration.api_root_url, path, params, content_type)
      interpret_json_response(response, path)
    end

    def self.bulk_get(path, params, content_type='application/json')
      response = self._get(Zerobounce.configuration.bulk_api_root_url, path, params, content_type)
      if response.headers[:content_type] == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body)
        return response_body_json unless response_body_json.is_a?(Hash)

        raise (response_body_json['error']) if response_body_json.key?('error')
        raise (response_body_json['errors'][0]['error']) \
          if response_body_json.key?('errors') and \
            response_body_json['errors'].length > 0

        return response_body_json
      else
        if ResponseError.html?(response.body, response.headers[:content_type])
          raise ResponseError.message_from(response)
        end
        content = StringIO.new(response.body)
        content.set_encoding_by_bom
        return content.string
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

    def self.bulk_post(path, params, content_type='application/json', filepath=nil)
      response = self._post(Zerobounce.configuration.bulk_api_root_url, path, params, \
          content_type, filepath)
      if response.headers[:content_type] == 'application/json'
        return __parse_json_response__(response)
      end
      return response.body
    end

    def self.bulk_root_get(path, params, content_type='application/json')
      response = self._get(bulk_api_root_without_v2, path, params, content_type)
      if response.headers[:content_type] == 'application/json'
        return __parse_json_response__(response)
      end
      response.body
    end

    def self.bulk_root_getfile(path, params)
      response = self._get(bulk_api_root_without_v2, path, params, 'application/json')
      GetFileHelper.process_getfile_response(response)
    end

    def self.bulk_root_post(path, params, content_type='application/json', filepath=nil)
      response = self._post(bulk_api_root_without_v2, path, params, content_type, filepath)
      if response.headers[:content_type] == 'application/json'
        return __parse_json_response__(response)
      end
      response.body
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
        raise ResponseError.message_from_parts(response.code, content_type, body)
      end
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        raise 'ZeroBounce returned a response that is not valid JSON.'
      end
      return parsed unless parsed.is_a?(Hash)

      raise ResponseError.strip_prefix(parsed['error']) if parsed.key?('error') && !parsed['error'].nil?
      if parsed.key?('Message') && parsed.length == 1
        raise ResponseError.strip_prefix(parsed['Message'])
      end
      if parsed.key?('errors') && parsed['errors'].is_a?(Array) && !parsed['errors'].empty?
        account = parsed['errors'].find { |item| item.is_a?(Hash) && item['email_address'].to_s.casecmp('all').zero? }
        if account
          raise ResponseError.strip_prefix(account['error'])
        end
        raise ResponseError.strip_prefix(parsed['errors'][0]['error']) unless path == 'validatebatch'
      end
      parsed
    end

  end

end
