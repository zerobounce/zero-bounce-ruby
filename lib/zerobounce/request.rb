# frozen_string_literal: true

# https://github.com/rest-client/rest-client
require 'rest-client'

require 'json'

module Zerobounce
  # Sends the HTTP request.
  #
  # @author Aaron Frase
  #
  # @attr_reader [String] host
  #   The host to send the request to.
  #
  # @attr_reader [Hash] headers
  #   The headers used for the request.
  class Request
    attr_reader :host
    attr_reader :headers

    VALID_GET_PARAMS = %i[api_key ip_address email].freeze

    # Set instance variables and extends the correct Zerobounce::Request
    #
    # @param [Hash] params
    # @option params [String] :headers default: {Configuration#headers} {include:#headers}
    # @option params [String] :host default: {Configuration#host} {include:#host}
    def initialize(params={})
      @headers = params[:headers] || Zerobounce.config.headers
      @host = params[:host] || Zerobounce.config.host
    end

    # Validate the email address.
    #
    # @param [Hash] params
    # @option params [String] :email
    # @option params [String] :ip_address
    # @option params [String] :api_key
    # @return [Zerobounce::Response]
    def validate(params)
      Response.new(get('validate', params), self)
    end

    # Get the number of remaining credits on the account.
    #
    # @param [Hash] params
    # @option params [String] :apikey
    # @return [Integer] A value of -1 can mean the API is invalid.
    def credits(params={})
      response = get('getcredits', params)
      response_body = response.body
      response_body_json = JSON.parse(response_body)
      credits = response_body_json[:Credits]
      credits_i = credits.to_i
      return credits_i
    end

    private

    # @param [Hash] params
    # @return [Hash]
    def get_params(params)
      # params[:ip_address] ||= '' # ip_address must be in query string
      # no it doesn't
      # params[:api_key] = params.delete(:apikey) if params.key?(:apikey) # normalize api_key param
      { api_key: Zerobounce.config.apikey }.merge(params.select { |k, _| VALID_GET_PARAMS.include?(k) })
    end

    # Sends a GET request.
    #
    # @param [Hash] params
    # @param [String] path
    # @return [Zerobounce::Response]
    def get(path, params)
      # conn.get(path, get_params(params))
      url = "#{host}/v2/#{path}"
      RestClient.get(url, {params: get_params(params)})
    end

    def post_form(path, params, file=nil)
      url = "#{host}/v2/#{path}"
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
      url = "#{host}/v2/#{path}"
      # RestClient.post "http://example.com/resource", {'x' => 1}.to_json, {content_type: :json, accept: :json}
    end
  end
end
