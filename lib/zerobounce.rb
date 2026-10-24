
# frozen_string_literal: true

require 'date'
require 'tempfile'

require 'zerobounce/error'
require 'zerobounce/response_error'
require 'zerobounce/client'
require 'zerobounce/version'
require 'zerobounce/download_type'
require 'zerobounce/get_file_options'
require 'zerobounce/get_file_helper'
require 'zerobounce/validate_status'
require 'zerobounce/validate_sub_status'
require 'zerobounce/request'
require 'zerobounce/mock_request'
require 'zerobounce/configuration'
require 'zerobounce/api_urls'
require 'zerobounce/priority3'
require 'zerobounce/warmup'

# Validate an email address with Zerobounce.net
module Zerobounce

  class << self
    include Priority3
    attr_writer :configuration

    @@request = ENV['TEST']=='unit' ? MockRequest : Request

    # Zerobounce configuration
    #
    # @return [Zerobounce::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end
    alias config configuration

    # Whether a getfile response body looks like a JSON error payload (including HTTP 200).
    #
    # @param [String] body
    # @return [Boolean]
    def get_file_json_indicates_error?(body)
      GetFileHelper.json_indicates_error?(body)
    end

    # Configure Zerobounce inside a block.
    #
    # @example
    #   Zerobounce.configure do |config|
    #     config.apikey = 'api-key'
    #   end
    #
    # @yieldparam [Zerobounce::Configuration] config
    def configure
      yield configuration
    end

    # Run a block with an API key that is visible only on this thread.
    def with_api_key(api_key)
      previous = Thread.current[:zerobounce_api_key]
      Thread.current[:zerobounce_api_key] = api_key
      yield
    ensure
      Thread.current[:zerobounce_api_key] = previous
    end

    # Validates the email address and gets geoip information for an IP if provided.
    #
    # @param [String] :email The email address to validate.
    # @option [String] :ip_address IP address corresponding to the email.
    #
    # @return [Hash]
    # {
    #   "address": "valid@example.com",
    #   "status": "valid",
    #   "sub_status": "",
    #   "free_email": false,
    #   "did_you_mean": null,
    #   "account": null,
    #   "domain": null,
    #   "domain_age_days": "9692",
    #   "smtp_provider": "example",
    #   "catchall_domain": false,
    #   "mx_found": "true",
    #   "mx_record": "mx.example.com",
    #   "firstname": "zero",
    #   "lastname": "bounce",
    #   "gender": "male",
    #   "country": null,
    #   "region": null,
    #   "city": null,
    #   "zipcode": null,
    #   "processed_at": "2023-04-18 12:09:39.074"
    # }
    def validate(email, ip_address=nil, timeout: nil, activity_data: nil, verify_plus: nil,
                 domain_info: nil, greylist_processing: nil, callback_url: nil, use_post: false)
      unless timeout.nil?
        timeout_i = Integer(timeout)
        if timeout_i < 3 || timeout_i > 60
          raise ArgumentError, 'Invalid parameter: timeout (must be between 3 and 60 seconds)'
        end
      end
      unless callback_url.nil?
        raise ArgumentError, 'Empty parameter: callback_url' if callback_url.to_s.strip.empty?

        # The callback is where the greylist retry posts its result, so it is
        # meaningless - and rejected by the API - without the retry itself.
        unless greylist_processing
          raise ArgumentError, 'callback_url requires greylist_processing to be true'
        end
      end
      params = {email: email, ip_address: ip_address}
      params[:timeout] = timeout unless timeout.nil?
      unless activity_data.nil?
        params[:activity_data] = activity_data ? 'true' : 'false'
      end
      unless verify_plus.nil?
        params[:verify_plus] = verify_plus ? 'true' : 'false'
      end
      unless domain_info.nil?
        params[:domain_info] = domain_info ? 'true' : 'false'
      end
      unless greylist_processing.nil?
        params[:greylist_processing] = greylist_processing ? 'true' : 'false'
      end
      params[:callback_url] = callback_url unless callback_url.nil?
      if use_post
        @@request.post('validate', params, 'application/x-www-form-urlencoded')
      else
        @@request.get('validate', params)
      end
    end

    # Get the number of remaining credits on the account.
    #
    # @return [Integer] amount of credits left
    def credits()
      json = @@request.get('getcredits', {})
      credits = json['Credits']
      credits_i = credits.to_i
      return credits_i
    end

    # Convenience method for checking if an email address is valid.
    #
    # @param [String] email
    # @return [Boolean]
    # def valid?(email)
    #   # todo:
    #   validate(email: email).valid?
    # end

    # Convenience method for checking if an email address is invalid.
    #
    # @param [String] email
    # @return [Boolean]
    # def invalid?(email)
    #   # todo:
    #   validate(email: email).invalid?
    # end

    # Get API usage
    #
    # @param [Date] start_date
    # @param [Date] end_date
    #
    # @return [Hash]
    # {
    #   "total": 5,
    #   "status_valid": 4,
    #   "status_invalid": 1,
    #   "status_catch_all": 0,
    #   "status_do_not_mail": 0,
    #   "status_spamtrap": 0,
    #   "status_unknown": 0,
    #   "sub_status_toxic": 0,
    #   "sub_status_disposable": 0,
    #   "sub_status_role_based": 0,
    #   "sub_status_possible_trap": 0,
    #   "sub_status_global_suppression": 0,
    #   "sub_status_timeout_exceeded": 0,
    #   "sub_status_mail_server_temporary_error": 0,
    #   "sub_status_mail_server_did_not_respond": 0,
    #   "sub_status_greylisted": 0,
    #   "sub_status_antispam_system": 0,
    #   "sub_status_does_not_accept_mail": 0,
    #   "sub_status_exception_occurred": 0,
    #   "sub_status_failed_syntax_check": 1,
    #   "sub_status_mailbox_not_found": 0,
    #   "sub_status_unroutable_ip_address": 0,
    #   "sub_status_possible_typo": 0,
    #   "sub_status_no_dns_entries": 0,
    #   "sub_status_role_based_catch_all": 0,
    #   "sub_status_mailbox_quota_exceeded": 0,
    #   "sub_status_forcible_disconnect": 0,
    #   "sub_status_failed_smtp_connection": 0,
    #   "sub_status_accept_all": 0,
    #   "sub_status_mx_forward": 0,
    #   "sub_status_alternate": 0,
    #   "sub_status_allowed": 0,
    #   "sub_status_blocked": 0,
    #   "sub_status_gold": 0,
    #   "sub_status_role_based_accept_all": 0,
    #   "start_date": "1/1/2018",
    #   "end_date": "12/12/2023"
    # }
    def api_usage(start_date, end_date)
      begin
        start_date_f = start_date.strftime('%Y-%m-%d')
        end_date_f = end_date.strftime('%Y-%m-%d')
      rescue NoMethodError => e
        raise ArgumentError.new('strftime method not found for provided arguments')
      end
      params = {start_date: start_date_f, end_date: end_date_f}
      @@request.get('getapiusage', params)
    end

    # Get Activty for email
    #
    # @param [String] :email Email to get activity for
    #
    # @return [Hash]
    # {
    #   "found": true,
    #   "active_in_days": "180"
    # }
    def activity(email)
      params = {email: email}
      @@request.get('activity', params)
    end

    # Real-time AI scoring for a single email (GET /scoring by default).
    #
    # @param [String] :email Email to score
    # @param [Boolean] :use_post When true, uses POST /scoring with form body
    #
    # @return [Hash] e.g. {"email"=>"mark@gmail.com", "score"=>10}
    def score_email(email, use_post: false)
      params = { email: email }
      if use_post
        @@request.post('scoring', params, 'application/x-www-form-urlencoded')
      else
        @@request.get('scoring', params)
      end
    end

    # Validate email batch
    #
    # @param [Array] :emails List of email addresses to validate.
    # @option [Array] :ip_addresses Corresponding list of IP addresses.
    #
    # @return [Array] list of validate result for each element
    # [
    #   {
    #     "address": "disposable@example.com",
    #     "status": "do_not_mail",
    #     "sub_status": "disposable",
    #     "free_email": false,
    #     "did_you_mean": null,
    #     "account": null,
    #     "domain": null,
    #     "domain_age_days": "9692",
    #     "smtp_provider": "example",
    #     "catchall_domain": false,
    #     "mx_found": "true",
    #     "mx_record": "mx.example.com",
    #     "firstname": "zero",
    #     "lastname": "bounce",
    #     "gender": "male",
    #     "country": null,
    #     "region": null,
    #     "city": null,
    #     "zipcode": null,
    #     "processed_at": "2023-04-18 12:27:39.529"
    #   },
    #   {
    #     ...
    #   },
    #   ...
    # ]
    def validate_batch(emails, ip_addresses=[], timeout: nil, activity_data: nil, verify_plus: nil)
      unless timeout.nil?
        timeout_i = Integer(timeout)
        if timeout_i < 10 || timeout_i > 120
          raise ArgumentError, 'Invalid parameter: timeout (must be between 10 and 120 seconds)'
        end
      end

      raise ArgumentError.new if emails.class != Array
      emails.each do |email|
        raise ArgumentError if email.class != String
      end

      email_batch = []
      emails.each_index do |i|
        email_batch.push({
          email_address: emails[i],
          ip_address: ip_addresses[i]
        })
      end
      params = {email_batch: email_batch}
      # LIVE: validatebatch takes timeout as a JSON *string*. Sent as a number
      # the API rejects the whole batch with the account-level "Invalid API Key
      # or your account ran out of credits".
      params[:timeout] = timeout.to_s unless timeout.nil?
      params[:activity_data] = activity_data unless activity_data.nil?
      params[:verify_plus] = verify_plus unless verify_plus.nil?
      results = @@request.post('validatebatch', params)
      results
    end

    # Validate CSV file
    #
    # @param [String] :filepath Path to the file to be uploaded
    # @option [Int] :email_address_column Specify which column the email address is on
    # @option [Int] :first_name_column Specify which column the first name is on
    # @option [Int] :last_name_column Specify which column the last name is on
    # @option [Int] :gender_column Specify which column the gender is on
    # @option [Int] :has_header_row Specify whether the file includes a header row or not
    # @option [Int] :return_url Specify a callback URL (if nil, no callback will be performed)
    #
    # @return [Hash]
    # {
    #     "success": true,
    #     "message": "File Accepted",
    #     "file_name": "zerobounce-batch-validation.csv",
    #     "file_id": "6d44a908-7283-42a9-aa5f-9e57b16f84bd"
    # }
    def validate_file_send(
        filepath,
        email_address_column: 1,
        first_name_column: 2,
        last_name_column: 3,
        gender_column: 4,
        has_header_row: true,
        return_url: nil,
        allow_phase_2: nil
      )
      params = {
        email_address_column: email_address_column,
        has_header_row: has_header_row,
      }
      params[:first_name_column] = first_name_column unless first_name_column.nil?
      params[:last_name_column] = last_name_column unless last_name_column.nil?
      params[:gender_column] = gender_column unless gender_column.nil?
      params[:return_url] = return_url unless return_url.nil? || return_url.to_s.empty?
      unless allow_phase_2.nil?
        params[:allow_phase_2] = allow_phase_2 ? 'true' : 'false'
      end
      @@request.bulk_post('sendfile', params, 'multipart/form-data', filepath)
    end

    # Validate CSV from a stream (IO or String).
    #
    # @param [IO, String] io Stream or string content to upload
    # @param [String] file_name Filename for the upload (e.g. "emails.csv")
    # @option [Int] :email_address_column (same as validate_file_send)
    # @option [Int] :first_name_column
    # @option [Int] :last_name_column
    # @option [Int] :gender_column
    # @option [Int] :has_header_row
    # @option [Int] :return_url
    # @option [Boolean] :allow_phase_2 When set, sends allow_phase_2 (validation bulk only).
    # @return [Hash] same as validate_file_send
    def validate_file_send_stream(io, file_name, **opts)
      content = io.respond_to?(:read) ? io.read : io.to_s
      Tempfile.create(['zb', File.extname(file_name)]) do |tmp|
        tmp.binmode
        tmp.write(content)
        tmp.rewind
        validate_file_send(tmp.path, **opts)
      end
    end

    # Get validate file status
    #
    # @param [String] :file_id Id of the file.
    #
    # @return [Hash]
    # {
    #     "success": true,
    #     "file_id": "6d44a908-7283-42a9-aa5f-9e57b16f84bd",
    #     "file_name": "zerobounce-batch-validation.csv",
    #     "upload_date": "2023-04-18T14:40:08Z",
    #     "file_status": "Complete",
    #     "complete_percentage": "100%",
    #     "error_reason": null,
    #     "return_url": null
    # }
    def validate_file_check(file_id)
      # todo:
      params = {file_id: file_id}
      @@request.bulk_get('filestatus', params)
    end

    # Get validate results file
    #
    # @param [String] file_id Id of the file.
    # @param [Zerobounce::GetFileOptions, nil] options Optional +download_type+ and +activity_data+ (validation bulk only).
    #
    # @return [String] file body on success
    # @raise [RuntimeError] on API/JSON error responses
    def validate_file_get(file_id, options = nil)
      params = { file_id: file_id }
      if options
        params[:download_type] = options.download_type if options.download_type
        unless options.activity_data.nil?
          params[:activity_data] = options.activity_data ? 'true' : 'false'
        end
      end
      @@request.bulk_getfile('getfile', params)
    end

    # Delete validate file
    #
    # @param file_id Id of the file.
    #
    # @return [Hash]
    # {
    #   "success": true,
    #   "message": "File Deleted",
    #   "file_name": "zerobounce-batch-validation.csv",
    #   "file_id": "6d44a908-7283-42a9-aa5f-9e57b16f84bd"
    # }
    def validate_file_delete(file_id)
      # todo:
      params = {file_id: file_id}
      @@request.bulk_get('deletefile', params)
    end

    # Score CSV file
    #
    # @param [String] :filepath Path to the file to be uploaded
    # @option [Int] :email_address_column Specify which column the email address is on
    # @option [Int] :has_header_row Specify whether the file includes a header row or not
    # @option [Int] :return_url Specify a callback URL (if nil, no callback will be performed)
    #
    # @return [Hash]
    # {
    #     "success": true,
    #     "message": "File Accepted",
    #     "file_name": "zerobounce-ai-scoring.csv",
    #     "file_id": "6d44a908-7283-42a9-aa5f-9e57b16f84bd"
    # }
    def scoring_file_send(
        filepath,
        email_address_column: 1,
        has_header_row: true,
        return_url: nil
      )
      params = {
        email_address_column: email_address_column,
        has_header_row: has_header_row,
      }
      params[:return_url] = return_url if return_url
      @@request.bulk_post('scoring/sendfile', params, 'multipart/form-data', filepath)
    end

    # Score CSV from a stream (IO or String).
    #
    # @param [IO, String] io Stream or string content to upload
    # @param [String] file_name Filename for the upload (e.g. "emails.csv")
    # @option [Int] :email_address_column (same as scoring_file_send)
    # @option [Int] :has_header_row
    # @option [Int] :return_url
    # @return [Hash] same as scoring_file_send
    def scoring_file_send_stream(io, file_name, **opts)
      content = io.respond_to?(:read) ? io.read : io.to_s
      Tempfile.create(['zb', File.extname(file_name)]) do |tmp|
        tmp.binmode
        tmp.write(content)
        tmp.rewind
        scoring_file_send(tmp.path, **opts)
      end
    end

    # Get scoring bulk results file
    #
    # @param [String] file_id Id of the file.
    # @param [Zerobounce::GetFileOptions, nil] options Optional +download_type+; +activity_data+ is not sent.
    #
    # @return [String] file body on success
    # @raise [RuntimeError] on API/JSON error responses
    def scoring_file_get(file_id, options = nil)
      params = { file_id: file_id }
      if options && options.download_type
        params[:download_type] = options.download_type
      end
      @@request.bulk_getfile('scoring/getfile', params)
    end

    # Get validate file status
    #
    # @param [String] :file_id Id of the file.
    #
    # @return [Hash]
    # {
    #   "success": true,
    #   "file_id": "d391b463-cb56-4fb3-a9c0-9817653ff725",
    #   "file_name": "zerobounce-ai-scoring.csv",
    #   "upload_date": "2023-04-18T15:13:56Z",
    #   "file_status": "Complete",
    #   "complete_percentage": "100% Complete.",
    #   "return_url": null
    # }
    def scoring_file_check(file_id)
      params = {file_id: file_id}
      @@request.bulk_get('scoring/filestatus', params)
    end

    # Delete validate file
    #
    # @param file_id Id of the file.
    #
    # @return [Hash]
    # {
    #   "success": true,
    #   "message": "File Deleted",
    #   "file_name": "zerobounce-ai-scoring.csv",
    #   "file_id": "6d44a908-7283-42a9-aa5f-9e57b16f84bd"
    # }
    def scoring_file_delete(file_id)
      params = {file_id: file_id}
      @@request.bulk_get('scoring/deletefile', params)
    end

    # Guess email formatDomain to guess format for
    #
    # @param [String] domain Domain to guess format for
    #
    # @option [String] first_name   First name of target.
    # @option [String] middle_name  Middle name of target.
    # @option [String] last_name    Last name of target.
    #
    # @return [Hash]
    # {
    # 	"email"=>"",
    #   "domain"=>"zerobounce.net",
    #   "format"=>"first.last",
    #    "status"=>"",
    #    "sub_status"=>"",
    #    "confidence"=>"high",
    #    "did_you_mean"=>"",
    #    "failure_reason"=>"",
    #    "other_domain_formats"=> [
    # 	    {"format"=>"first", "confidence"=>"high"},
    # 	    {"format"=>"last.first", "confidence"=>"high"},
    # 	    {"format"=>"lfirst", "confidence"=>"high"},
    # 	    {"format"=>"lastfirst", "confidence"=>"high"},
    # 	    {"format"=>"firstl", "confidence"=>"high"},
    # 	    {"format"=>"last", "confidence"=>"medium"},
    # 	    {"format"=>"first.middle.last", "confidence"=>"medium"},
    # 	    {"format"=>"first-last", "confidence"=>"medium"},
    # 	    {"format"=>"l.first", "confidence"=>"medium"},
    # 	    {"format"=>"f.last", "confidence"=>"medium"},
    # 	    {"format"=>"f-last", "confidence"=>"medium"},
    # 	    {"format"=>"first.l", "confidence"=>"medium"},
    # 	    {"format"=>"first-l", "confidence"=>"medium"},
    # 	    {"format"=>"firstlast", "confidence"=>"medium"},
    # 	    {"format"=>"first_l", "confidence"=>"medium"},
    # 	    {"format"=>"f_last", "confidence"=>"medium"},
    # 	    {"format"=>"last.f", "confidence"=>"medium"},
    # 	    {"format"=>"last-f", "confidence"=>"medium"},
    # 	    {"format"=>"last-first", "confidence"=>"medium"},
    # 	    {"format"=>"first_last", "confidence"=>"medium"},
    # 	    {"format"=>"last_f", "confidence"=>"medium"},
    # 	    {"format"=>"last_first", "confidence"=>"medium"},
    # 	    {"format"=>"flast", "confidence"=>"medium"},
    # 	    {"format"=>"lastf", "confidence"=>"medium"},
    # 	    {"format"=>"l-first", "confidence"=>"low"},
    # 	    {"format"=>"l_first", "confidence"=>"low"}
    #    ]
    # }
    def guessformat(domain, first_name: '', middle_name: '', last_name: '')
      warn "[DEPRECATION] `guessformat` is deprecated and will be removed in a future version.\n" \
           "Please use `find_email` or `find_domain` instead."
      params = {domain: domain}
      params[:first_name] = first_name unless first_name.nil? || first_name.empty?
      params[:middle_name] = middle_name unless middle_name.nil? || middle_name.empty?
      params[:last_name] = last_name unless last_name.nil? || last_name.empty?  
      @@request.get('guessformat', params)
    end


    # Find email address format
    #
    # @option [String] domain Domain to search within (e.g. example.com). Required if company_name is not provided.
    # @option [String] company_name Company name to search within (e.g. Example). Required if domain is not provided.
    # @option [String] first_name First name of target.
    # @option [String] middle_name Middle name of target.
    # @option [String] last_name Last name of target.
    #
    # @return [Hash]
    # {
    #   "email": "john@zerobounce.net",
    #   "email_confidence": "medium",
    #   "domain": "zerobounce.net",
    #   "company_name": "ZeroBounce",
    #   "did_you_mean": "",
    #   "failure_reason": ""
    # }
    def find_email(first_name, domain: '', company_name: '', middle_name: '', last_name: '')
      # Validate that exactly one of domain or company_name is provided
      if (domain.nil? || domain.empty?) && (company_name.nil? || company_name.empty?)
        raise ArgumentError, "Either domain or company_name must be provided"
      elsif !(domain.nil? || domain.empty?) && !(company_name.nil? || company_name.empty?)
        raise ArgumentError, "Only one of domain or company_name can be provided"
      end

      params = { first_name: first_name }
      params[:domain] = domain unless domain.nil? || domain.empty?
      params[:company_name] = company_name unless company_name.nil? || company_name.empty?
      params[:middle_name] = middle_name unless middle_name.nil? || middle_name.empty?
      params[:last_name] = last_name unless last_name.nil? || last_name.empty?

      @@request.get('guessformat', params)
    end

    # Find domain format
    # 
    # @option [String] domain Domain to search within (e.g. example.com). Required if company_name is not provided.
    # @option [String] company_name Company name to search within (e.g. Example). Required if domain is not provided.
    # 
    # @return [Hash]
    # {
    #   "domain": "zerobounce.net",
    #   "company_name": "Hertza, LLC",
    #   "format": "first.last",
    #   "confidence": "high",
    #   "did_you_mean": "",
    #   "failure_reason": "",
    #   "other_domain_formats": [
    #     {"format": "first", "confidence": "high"},
    #     {"format": "last.first", "confidence": "high"},
    #     {"format": "lastfirst", "confidence": "high"},
    #     {"format": "firstl", "confidence": "high"},
    #     {"format": "lfirst", "confidence": "high"},
    #     {"format": "firstlast", "confidence": "high"},
    #     {"format": "last_middle_f", "confidence": "high"},
    #     {"format": "last", "confidence": "high"},
    #     {"format": "f.last", "confidence": "medium"},
    #     {"format": "last-f", "confidence": "medium"},
    #     {"format": "l.first", "confidence": "medium"},
    #     {"format": "last_f", "confidence": "medium"},
    #     {"format": "first.middle.last", "confidence": "medium"},
    #     {"format": "first-last", "confidence": "medium"},
    #     {"format": "last.f", "confidence": "medium"},
    #     {"format": "last_first", "confidence": "medium"},
    #     {"format": "f-last", "confidence": "medium"},
    #     {"format": "first.l", "confidence": "medium"},
    #     {"format": "first-l", "confidence": "medium"},
    #     {"format": "first_l", "confidence": "medium"},
    #     {"format": "first_last", "confidence": "medium"},
    #     {"format": "f_last", "confidence": "medium"},
    #     {"format": "last-first", "confidence": "medium"},
    #     {"format": "flast", "confidence": "medium"},
    #     {"format": "lastf", "confidence": "medium"},
    #     {"format": "l_first", "confidence": "medium"},
    #     {"format": "l-first", "confidence": "medium"},
    #     {"format": "first-middle-last", "confidence": "low"},
    #     {"format": "firstmlast", "confidence": "low"},
    #     {"format": "last.middle.first", "confidence": "low"},
    #     {"format": "last_middle_first", "confidence": "low"},
    #     {"format": "first_middle_last", "confidence": "low"},
    #     {"format": "last-middle-first", "confidence": "low"},
    #     {"format": "first-m-last", "confidence": "low"},
    #     {"format": "firstmiddlelast", "confidence": "low"},
    #     {"format": "last.m.first", "confidence": "low"},
    #     {"format": "lastmfirst", "confidence": "low"},
    #     {"format": "lastmiddlefirst", "confidence": "low"},
    #     {"format": "last_m_first", "confidence": "low"},
    #     {"format": "first.m.last", "confidence": "low"},
    #     {"format": "first_m_last", "confidence": "low"},
    #     {"format": "last-m-first", "confidence": "low"}
    #   ]
    # }
    def find_domain(domain: '', company_name: '')
      # Validate that exactly one of domain or company_name is provided
      if (domain.nil? || domain.empty?) && (company_name.nil? || company_name.empty?)
        raise ArgumentError, "Either domain or company_name must be provided"
      elsif !(domain.nil? || domain.empty?) && !(company_name.nil? || company_name.empty?)
        raise ArgumentError, "Only one of domain or company_name can be provided"
      end

      params = {}
      params[:domain] = domain unless domain.nil? || domain.empty?
      params[:company_name] = company_name unless company_name.nil? || company_name.empty?

      @@request.get('guessformat', params)
    end

  end
end
