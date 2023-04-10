# frozen_string_literal: true

require 'faraday'

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
  #
  # @attr_reader [Proc] middleware
  #   Faraday middleware used for the request.
  class Request
    attr_reader :host
    attr_reader :headers
    attr_reader :middleware

    VALID_GET_PARAMS = %i[api_key ip_address email].freeze

    # Set instance variables and extends the correct Zerobounce::Request
    #
    # @param [Hash] params
    # @option params [String] :middleware default: {Configuration#middleware} {include:#middleware}
    # @option params [String] :headers default: {Configuration#headers} {include:#headers}
    # @option params [String] :host default: {Configuration#host} {include:#host}
    def initialize(params={})
      @middleware = params[:middleware] || Zerobounce.config.middleware
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
      get('getcredits', params).body[:Credits].to_i
    end

    private

    # @param [Hash] params
    # @return [Hash]
    def get_params(params)
      params[:ip_address] ||= '' # ip_address must be in query string
      params[:api_key] = params.delete(:apikey) if params.key?(:apikey) # normalize api_key param
      { api_key: Zerobounce.config.apikey }.merge(params.select { |k, _| VALID_GET_PARAMS.include?(k) })
    end

    # Sends a GET request.
    #
    # @param [Hash] params
    # @param [String] path
    # @return [Zerobounce::Response]
    def get(path, params)
      conn.get(path, get_params(params))
    end

    # @return [Faraday::Connection]
    def conn
      @conn ||= Faraday.new("#{host}/v2", headers: headers, &middleware)
    end
  end
end
