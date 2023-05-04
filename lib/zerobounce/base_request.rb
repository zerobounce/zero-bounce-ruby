# frozen_string_literal: true

require 'json'

# https://github.com/rest-client/rest-client
require 'rest-client'


module Zerobounce
  
  # Sends the HTTP request.
  class BaseRequest

    protected 

    def self._get(root, path, params, content_type='application/json')

      # puts path
      # puts Zerobounce.config.apikey

      raise ("API key must be assigned") if not Zerobounce.config.apikey

      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"

      response = RestClient.get(url, {params: params})
      return response
    end

    def self._post(root, path, params, content_type='application/json', filepath=nil)

      raise ("API key must be assigned") if not Zerobounce.config.apikey

      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"
      response = nil

      if filepath or content_type == 'multipart/form-data'
        params[:file] = File.new(filepath, 'rb')
        params[:multipart] = true
        response = RestClient.post(url, params)

      elsif content_type == 'application/json'
        response = RestClient.post(url, params.to_json, \
                      content_type: :json, accept: :json)
      else
        # this shouldn't happen
        raise Error.new('Unknown content type specified in request.'\
          ' Must be either multipart/form-data or application/json.')
      end
      return response
    end

  end
end