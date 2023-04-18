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

    # def self.post(path, params, content_type='application/json', file=nil)
    #   self._post(Zerobounce::BULK_API_ROOT_URL, path, params, content_type, file)
    # end

    def self.bulk_get(path, params, content_type='application/json')
      self._get(Zerobounce::BULK_API_ROOT_URL, path, params, content_type)
    end

    def self.bulk_post(root, path, params, content_type='application/json', file)
      self._post(Zerobounce::BULK_API_ROOT_URL, path, params, content_type, file)
    end

    private 

    def self._get(root, path, params, content_type)
      # todo: check params with param definitions
      # todo: check api key
      # todo: use multiple hosts (api, bulk api)
      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"
      response = RestClient.get(url, {params: params})
      if content_type == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body) 
        return response_body_json
      end
      return response
    end

    def self._post(root, path, params, content_type, file)
      params[:api_key] = Zerobounce.config.apikey
      url = "#{root}/#{path}"
      # RestClient.post '/data', :myfile => File.new("/path/to/image.jpg", 'rb')
      # RestClient.post '/data', {:foo => 'bar', :multipart => true}
=begin
      RestClient.post( url,
      {
        :transfer => {
          :path => '/foo/bar',
          :owner => 'that_guy',
          :group => 'those_guys'
        },
         :upload => {
          :file => File.new(path, 'rb')
        }
      })
=end
# RestClient.post "http://example.com/resource", {'x' => 1}.to_json, {content_type: :json, accept: :json}
    end

  end

end
