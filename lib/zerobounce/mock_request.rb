# frozen_string_literal: true

require 'zerobounce/base_request'
require 'zerobounce/get_file_helper'

module Zerobounce

  # Sends the HTTP request.
  class MockRequest < BaseRequest

    def self.get(path, params, content_type='application/json')
      response = self._get(Zerobounce.configuration.api_root_url, path, params, content_type)
      if response.headers[:content_type] == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body)

        raise (response_body_json['error']) if response_body_json.key?('error')
        raise (response_body_json['errors'][0]['error']) \
          if response_body_json.key?('errors') and \
            response_body_json['errors'].length > 0

        return response_body_json
      else
        return response
      end
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
        return response.body
      end
    end

    def self.bulk_getfile(path, params)
      response = self._get(Zerobounce.configuration.bulk_api_root_url, path, params, 'application/json')
      GetFileHelper.process_getfile_response(response)
    end

    def self.post(path, params, content_type='application/json', filepath=nil)
      response = self._post(Zerobounce.configuration.api_root_url, path, params, \
          content_type, filepath)
      if response.headers[:content_type] == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body)

        raise (response_body_json['error']) if response_body_json.key?('error')
        raise (response_body_json['errors'][0]['error']) \
          if response_body_json.key?('errors') and \
            response_body_json['errors'].length > 0

        return response_body_json
      end
      return response.body
    end

    def self.bulk_post(path, params, content_type='application/json', filepath=nil)
      response = self._post(Zerobounce.configuration.bulk_api_root_url, path, params, \
          content_type, filepath)
      if response.headers[:content_type] == 'application/json'
        return __parse_json_response__(response)
      end
      response.body
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

  end

end
