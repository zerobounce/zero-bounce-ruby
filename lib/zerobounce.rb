
# frozen_string_literal: true

require 'date'

require 'zerobounce/error'
require 'zerobounce/version'
require 'zerobounce/request'
require 'zerobounce/mock_request'
require 'zerobounce/configuration'

# Validate an email address with Zerobounce.net
module Zerobounce
  
  API_ROOT_URL      = 'https://api.zerobounce.net/v2'
  BULK_API_ROOT_URL = 'https://bulkapi.zerobounce.net/v2'

  class << self
    attr_writer :configuration

    @@request = ENV['TEST']=='unit' ? MockRequest : Request

    # Zerobounce configuration
    #
    # @return [Zerobounce::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end
    alias config configuration

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
    def validate(email, ip_address=nil)
      params = {email: email, ip_address: ip_address}
      @@request.get('validate', params)
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
    #   "sub_status_mx_forward": 0,
    #   "sub_status_alternate": 0,
    #   "sub_status_blocked": 0,
    #   "sub_status_allowed": 0,
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
    def validate_batch(emails, ip_addresses=[])

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
      results = @@request.bulk_post('validatebatch', params)
      return results['email_batch']
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
        return_url: nil
      )
      params = {
        email_address_column: email_address_column,
        first_name_column: first_name_column,
        last_name_column: last_name_column,
        gender_column: gender_column,
        has_header_row: has_header_row,
      }
      params[:return_url] = return_url if return_url
      @@request.bulk_post('sendfile', params, 'multipart/form-data', filepath)
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
    # @param [String] :file_id Id of the file.
    # 
    # @return [String/File?] 
    def validate_file_get(file_id)
      # todo:
      params = {file_id: file_id}
      @@request.bulk_get('getfile', params)
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

    # Get validate results file 
    # 
    # @param [String] :file_id Id of the file.
    # 
    # @return [String/File?] 
    def scoring_file_get(file_id)
      # todo:
      params = {file_id: file_id}
      @@request.bulk_get('scoring/getfile', params)
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
      # todo:
      params = {file_id: file_id}
      @@request.bulk_get('scoring/deletefile', params)
    end

  end
end
