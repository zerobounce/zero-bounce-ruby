# frozen_string_literal: true

require 'rest-client'
require 'dotenv'
require_relative 'api_urls'

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
  # @attr [String] api_root_url
  #   The Zerobounce API root URL. Defaults to ApiUrls::DEFAULT_URL.
  #
  # @attr [String] bulk_api_root_url
  #   The Zerobounce bulk API root URL.
  #
  # @attr [Array<Symbol>] valid_statues
  #   The statuses that are considered valid by {Response#valid?}.
  class Configuration
    attr_accessor :headers, :apikey, :api_root_url, :bulk_api_root_url, :valid_statuses, :mock

    def initialize(mock = false)
      File.file?('.env') ? Dotenv.load('.env') : Dotenv.load
      self.apikey = ENV['ZEROBOUNCE_API_KEY']
      self.api_root_url = ENV['ZEROBOUNCE_API_URL'] || ApiUrls::DEFAULT_URL
      self.bulk_api_root_url = ENV['ZEROBOUNCE_BULK_API_URL'] || ApiUrls::BULK_DEFAULT_URL
      self.valid_statuses = %i[valid catch_all]
      self.headers = { user_agent: "ZerobounceRubyGem/#{Zerobounce::VERSION}" }
      self.mock = mock
    end
  end
end
