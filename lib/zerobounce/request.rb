# frozen_string_literal: true

# https://github.com/rest-client/rest-client
require 'rest-client'

require 'json'

module Zerobounce
  
  # Sends the HTTP request.
  class Request

    # private

    # Sends a GET request.
    #
    # @param [Hash] params
    # @param [String] path
    # @return [Zerobounce::Response]
    def self.get(path, params, content_type='application/json')
      # todo: check params with param definitions
      # todo: check api key
      # todo: use multiple hosts (api, bulk api)
      params[:api_key] = Zerobounce.config.apikey
      url = "#{Zerobounce::API_ROOT_URL}/#{path}"
      response = RestClient.get(url, {params: params})
      if content_type == 'application/json'
        response_body = response.body
        response_body_json = JSON.parse(response_body) 
        return response_body_json
      end
      return response
    end

    def post_form(path, params, file=nil)
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
    end

    def post_json(path, params)
      # RestClient.post "http://example.com/resource", {'x' => 1}.to_json, {content_type: :json, accept: :json}
    end
  end
end
