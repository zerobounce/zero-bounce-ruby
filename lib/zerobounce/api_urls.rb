# frozen_string_literal: true

require 'ipaddr'
require 'uri'

module Zerobounce
  # API URL constants for Zerobounce endpoints
  #
  # This class provides constant values for different Zerobounce API endpoints
  # that can be accessed publicly by gem users.
  #
  class ApiUrls
    # API URLs
    DEFAULT_URL = 'https://api.zerobounce.net/v2/'
    EU_URL = 'https://api-eu.zerobounce.net/v2/'
    US_URL = 'https://api-us.zerobounce.net/v2/'

    # Bulk API URLs
    BULK_DEFAULT_URL = 'https://bulkapi.zerobounce.net/v2/'

    # The S3 and SFTP/FTP bulk jobs live on the bulkapi host WITHOUT the /v2
    # path. See https://www.zerobounce.net/docs/api-integrations.
    BULK_ROOT_URL = 'https://bulkapi.zerobounce.net/'

    # The list evaluator and the Inbox Placement Tester have their own base
    # URLs, not paths built from the bulk one.
    LIST_EVALUATOR_URL = 'https://bulkapi.zerobounce.net/v2/listevaluator/'
    INBOX_PLACEMENT_URL = 'https://bulkapi.zerobounce.net/api/ipt'

    # Whitespace of any kind, control and Unicode format characters.
    UNSAFE_URL_CHARACTERS = /[[:space:][:cntrl:]\p{Cf}\p{Zs}\p{Zl}\p{Zp}\u180e]/
    LABEL = '[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    HOST_LABELS = /\A#{LABEL}(?:\.#{LABEL})*\z/
    private_constant :UNSAFE_URL_CHARACTERS, :LABEL, :HOST_LABELS

    # The URL, unchanged, or an ArgumentError. Every request carries the API
    # key, so it is refused unless the URL is an absolute https:// URL with a
    # valid host and port, no userinfo (https://api.zerobounce.net@evil.example
    # would send the key to evil.example), no whitespace, control or format
    # characters and no backslash. Checked when a URL is configured and again
    # on every send.
    def self.check!(url, label = 'API URL')
      text = url.to_s
      raise ArgumentError, "#{label} must be an https:// URL" unless text.downcase.start_with?('https://')
      raise ArgumentError, "#{label} must be a valid https:// URL" unless safe_https?(text)

      url
    end

    def self.safe_https?(text) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return false if text.match?(UNSAFE_URL_CHARACTERS) || text.include?('\\') || !text.valid_encoding?

      authority = text[%r{\Ahttps://([^/?#]*)}i, 1]
      return false if authority.nil? || authority.empty? || authority.include?('@') || authority.end_with?(':')

      host, port = split_authority(authority)
      return false if host.nil? || (port && !(1..65_535).cover?(port.to_i))

      begin
        URI.parse(text)
      rescue URI::InvalidURIError
        return false
      end
      host.start_with?('[') ? ipv6?(host) : host.match?(HOST_LABELS)
    end

    def self.split_authority(authority)
      pattern = authority.start_with?('[') ? /\A(\[[^\]]*\])(?::(\d+))?\z/ : /\A([^:]+)(?::(\d+))?\z/
      match = authority.match(pattern)
      match && [match[1], match[2]]
    end

    def self.ipv6?(host)
      IPAddr.new(host[1..-2].split('%', 2).first).ipv6?
    rescue IPAddr::Error
      false
    end
    private_class_method :safe_https?, :split_authority, :ipv6?
  end
end
