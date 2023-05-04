# frozen_string_literal: true

require 'zerobounce/base_request'

module Zerobounce
  
  # Sends the HTTP request.
  class MockRequest < BaseRequest
    
    def self.get(path, params, content_type='application/json')
      response = self._get(Zerobounce::API_ROOT_URL, path, params, content_type)
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
      response = self._get(Zerobounce::BULK_API_ROOT_URL, path, params, content_type)
      if response.headers[:content_type] == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body)

        raise (response_body_json['error']) if response_body_json.key?('error')
        raise (response_body_json['errors'][0]['error']) \
          if response_body_json.key?('errors') and \
            response_body_json['errors'].length > 0

        return response_body_json
      else
        return response.body
      end
    end

    def self.bulk_post(path, params, content_type='application/json', filepath=nil)
      response = self._post(Zerobounce::BULK_API_ROOT_URL, path, params, \
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

  end

end
