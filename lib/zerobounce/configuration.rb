# frozen_string_literal: true

require 'rest-client'
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
  # @attr [String, nil] bulk_root_url
  #   The root for the S3 and SFTP/FTP bulk jobs: the bulkapi host without the
  #   /v2 path. Defaults to nil, which derives it from {#bulk_api_root_url}.
  #
  # @attr [Array<Symbol>] valid_statues
  #   The statuses that are considered valid by {Response#valid?}.
  class Configuration
    attr_accessor :headers, :apikey, :api_root_url, :bulk_api_root_url, :bulk_root_url,
                  :list_evaluator_root_url, :inbox_placement_root_url, :valid_statuses, :mock

    def initialize(mock = false)
      self.apikey = ENV['ZEROBOUNCE_API_KEY']
      self.api_root_url = ENV['ZEROBOUNCE_API_URL'] || ApiUrls::DEFAULT_URL
      self.bulk_api_root_url = ENV['ZEROBOUNCE_BULK_API_URL'] || ApiUrls::BULK_DEFAULT_URL
      # The S3/SFTP root is the only one that can be derived from another base
      # URL, so it is left unset unless it is asked for: BaseRequest then takes
      # bulk_api_root_url with the /v2 stripped. Set it - in code or through
      # ZEROBOUNCE_BULK_ROOT_URL - to point those jobs somewhere on their own.
      self.bulk_root_url = ENV['ZEROBOUNCE_BULK_ROOT_URL']
      # These two are separate base URLs rather than paths built from
      # bulk_api_root_url, so overriding that alone leaves them on the live API.
      self.list_evaluator_root_url = ENV['ZEROBOUNCE_LIST_EVALUATOR_URL'] || ApiUrls::LIST_EVALUATOR_URL
      self.inbox_placement_root_url = ENV['ZEROBOUNCE_INBOX_PLACEMENT_URL'] || ApiUrls::INBOX_PLACEMENT_URL
      self.valid_statuses = %i[valid catch_all accept_all]
      self.headers = { user_agent: "ZerobounceRubyGem/#{Zerobounce::VERSION}" }
      self.mock = mock
    end

    # Keep the API key out of logs, consoles and error pages that call #inspect.
    def inspect
      vars = instance_variables.map do |var|
        value = var == :@apikey && apikey ? '[FILTERED]' : instance_variable_get(var).inspect
        "#{var}=#{value}"
      end
      "#<#{self.class.name} #{vars.join(', ')}>"
    end
  end
end
