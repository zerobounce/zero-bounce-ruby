# frozen_string_literal: true

# https://github.com/rest-client/rest-client
require 'rest-client'

require 'json'

module Zerobounce
  
  # Sends the HTTP request.
  class Request

    def self.get(path, params, content_type='application/json')
      self._get(Zerobounce::API_ROOT_URL, path, params, content_type)
    end

    def self.bulk_get(path, params, content_type='application/json')
      self._get(Zerobounce::BULK_API_ROOT_URL, path, params, content_type)
    end

    def self.bulk_post(path, params, content_type='application/json', filepath=nil)
      self._post(Zerobounce::BULK_API_ROOT_URL, path, params, content_type, file)
    end

    private 

    def self._get(root, path, params, content_type='application/json')
      # todo: check params with param definitions
      # todo: check api key
      # todo: use multiple hosts (api, bulk api)
      
      raise ("API key must be assigned") if not Zerobounce.config.apikey

      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"
      response = RestClient.get(url, {params: params})
      if content_type == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body) 

        # puts response_body_json if response_body_json.key?('error')

        raise (response_body_json['error']) if response_body_json.key?('error')

        return response_body_json
      end
      return response
    end

    def self._post(root, path, params, content_type='application/json', filepath=nil)
      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"

      if filepath or content_type == 'multipart/form-data'
        params[:file] = File.new(filepath, 'rb')
        params[:multipart] = true
        RestClient.post(url, params)

      elsif content_type == 'application/json'
        RestClient.post(url, params.to_json, content_type: :json, accept: :json)

      else
        # this shouldn't happen
        raise Error.new('Unknown content type specified in request.'\
          ' Must be either multipart/form-data or application/json.')
      end
    end

  end

end
