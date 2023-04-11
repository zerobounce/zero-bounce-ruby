# frozen_string_literal: true

# https://github.com/rest-client/rest-client
require 'rest-client'

require 'json'

module Zerobounce
  # Sends the HTTP request.
  #
  # @attr_reader [String] host
  #   The host to send the request to.
  #
  # @attr_reader [Hash] headers
  #   The headers used for the request.
  class Request
    attr_reader :host
    attr_reader :headers

    # Set instance variables and extends the correct Zerobounce::Request
    #
    # @param [Hash] params
    # @option params [String] :headers default: {Configuration#headers} {include:#headers}
    # @option params [String] :host default: {Configuration#host} {include:#host}
    def initialize()
      @headers = Zerobounce.config.headers
      @host = Zerobounce.config.host
    end

    # Validate the email address.
    #
    # @option params [String] :email
    # @option params [String] :ip_address
    # @return [Zerobounce::Response]
    def validate(email, ip_address="")
      params = {email: email, ip_address: ip_address}
      get('validate', params)
    end

    # Get the number of remaining credits on the account.
    #
    # @return [Integer] A value of -1 can mean the API Key is invalid.
    def credits()
      json = get('getcredits', {})
      credits = json[:Credits]
      credits_i = credits.to_i
      return credits_i
    end

    private

    # Sends a GET request.
    #
    # @param [Hash] params
    # @param [String] path
    # @return [Zerobounce::Response]
    def get(path, params, content_type='application/json')
      # todo: check params with param definitions
      # todo: check api key
      # todo: use multiple hosts (api, bulk api)
      params[:api_key] = Zerobounce.config.apikey
      url = "#{host}/v2/#{path}"
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
