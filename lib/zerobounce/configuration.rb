# frozen_string_literal: true

require 'rest-client'

module Zerobounce
  # Configuration object for Zerobounce.
  #
  # @author Aaron Frase
  #
  # @attr [String] host
  #   The Zerobounce API host.
  #
  # @attr [Hash] headers
  #   Headers to use in all requests.
  #
  # @attr [String] apikey
  #   A Zerobounce API key.
  #
  # @attr [Array<Symbol>] valid_statues
  #   The statuses that are considered valid by {Response#valid?}.
  class Configuration
    attr_accessor :host
    attr_accessor :headers
    attr_accessor :apikey
    attr_accessor :valid_statuses
    attr_accessor :mock

    def initialize(mock=false)
      self.host = 'https://api.zerobounce.net'
      self.apikey = ENV['ZEROBOUNCE_API_KEY']
      self.valid_statuses = %i[valid catch_all]
      self.headers = { user_agent: "ZerobounceRubyGem/#{Zerobounce::VERSION}" }
      self.mock = mock
    end
  end
end
