# frozen_string_literal: true

require 'time'

module Zerobounce
  # A Zerobounce response
  #
  # @author Aaron Frase
  #
  # @attr_reader [Zerobounce::Request] request
  #   The request instance.
  #
  # @attr_reader [Faraday::Response] response
  #   The original {https://www.rubydoc.info/gems/faraday/1.4.2/Faraday/Response Faraday::Response}
  class Response
    attr_reader :response
    attr_reader :request

    # @param [Faraday::Response] response
    # @param [Zerobounce::Request::V2Response, Zerobounce::Request::V1Response] request
    def initialize(response, request)
      @response = response
      @request = request
      @body = response.body
    end

    # The email address you are validating.
    #
    # @return [String]
    def address
      @address ||= @body[:address]
    end

    # The portion of the email address before the "@" symbol.
    #
    # @return [String]
    def account
      @account ||= @body[:account]
    end

    # The portion of the email address after the "@" symbol.
    #
    # @return [String]
    def domain
      @domain ||= @body[:domain]
    end

    # The first name of the owner of the email when available.
    #
    # @return [String, nil]
    def firstname
      @firstname ||= @body[:firstname]
    end

    # The last name of the owner of the email when available.
    #
    # @return [String, nil]
    def lastname
      @lastname ||= @body[:lastname]
    end

    # The gender of the owner of the email when available.
    #
    # @return [String, nil]
    def gender
      @gender ||= @body[:gender]
    end

    # The country of the IP passed in.
    #
    # @return [String, nil]
    def country
      @country ||= @body[:country]
    end

    # The region/state of the IP passed in.
    #
    # @return [String, nil]
    def region
      @region ||= @body[:region]
    end

    # The city of the IP passed in.
    #
    # @return [String, nil]
    def city
      @city ||= @body[:city]
    end

    # The zipcode of the IP passed in.
    #
    # @return [String, nil]
    def zipcode
      @zipcode ||= @body[:zipcode]
    end

    # Is this email considered valid?
    #
    # @note Uses the values from {Zerobounce::Configuration#valid_statuses}
    #
    # @return [Boolean]
    def valid?
      @valid ||= Zerobounce.config.valid_statuses.include?(status)
    end

    # The opposite of {#valid?}
    #
    # @return [Boolean]
    def invalid?
      !valid?
    end

    # Returns a string containing a human-readable representation.
    #
    # @note Overriding inspect to hide the {#request}/{#response} instance variables
    #
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} @address=#{address}>"
    end

    # Convert to a hash.
    #
    # @return [Hash]
    def to_h
      public_methods(false).each_with_object({}) do |meth, memo|
        next if %i[request response inspect to_h].include?(meth)

        memo[meth] = send(meth)
      end
    end


    # Deliverability status
    #
    # @see https://www.zerobounce.net/docs/email-validation-api-quickstart/#status_codes__v2__
    #
    # Possible values:
    #   :valid
    #   :invalid
    #   :catch_all
    #   :unknown
    #   :spamtrap
    #   :abuse
    #   :do_not_mail
    #
    # @return [Symbol, nil] The status as a +Symbol+.
    def status
      @status ||= @body[:status].to_s.empty? ? nil : @body[:status].tr('-', '_').to_sym
    end

    # @return [Symbol, nil]
    def sub_status
      @sub_status ||= @body[:sub_status].to_s.empty? ? nil : @body[:sub_status].to_sym
    end

    # @return [Integer]
    def domain_age_days
      @domain_age_days ||= @body[:domain_age_days].to_i
    end

    # The SMTP Provider of the email.
    #
    # @return [String, nil]
    def smtp_provider
      @smtp_provider ||= @body[:smtp_provider]
    end

    # @return [String, nil]
    def did_you_mean
      @did_you_mean ||= @body[:did_you_mean]
    end

    # The preferred MX record of the domain.
    #
    # @return [String, nil]
    def mx_record
      @mx_record ||= @body[:mx_record]
    end

    # The UTC time the email was validated.
    #
    # @return [Time, nil]
    def processed_at
      @processed_at ||= @body[:processed_at] && Time.parse("#{@body[:processed_at]} UTC")
    end

    # If the email comes from a free provider.
    #
    # @return [Boolean]
    def free_email?
      @free_email ||= @body[:free_email] || false
    end

    # If the email domain is disposable, which are usually temporary email addresses.
    #
    # These are temporary emails created for the sole purpose to sign up to websites without giving their real
    # email address. These emails are short lived from 15 minutes to around 6 months.
    #
    # @note If you have valid emails with this flag set to +true+, you shouldn't email them.
    #
    # @return [Boolean]
    def disposable?
      @disposable ||= sub_status == :disposable
    end

    # These domains are known for abuse, spam, or are bot created.
    #
    # @note If you have a valid email with this flag set to +true+, you shouldn't email them.
    #
    # @return [Boolean]
    def toxic?
      @toxic ||= sub_status == :toxic
    end

    # Does the domain have an MX record.
    #
    # @return [Boolean]
    def mx_found?
      @mx_found ||= @body[:mx_found] == 'true'
    end
  end
end
