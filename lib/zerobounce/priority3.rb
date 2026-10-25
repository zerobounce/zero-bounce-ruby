# frozen_string_literal: true

require 'erb'

module Zerobounce
  module Priority3
    EMAIL_FINDER_BULK_BASE = 'email-finder'
    DOMAIN_SEARCH_BULK_BASE = 'domain-search'

    # Inbox Placement Tester bounds, as documented and as the API enforces them.
    INBOX_PLACEMENT_NAME_MAX = 64
    INBOX_PLACEMENT_TEST_TYPES = [1, 2, 3].freeze
    INBOX_PLACEMENT_PAGE_SIZE_MIN = 1
    INBOX_PLACEMENT_PAGE_SIZE_MAX = 100

    def zb_request
      Zerobounce.class_variable_get(:@@request)
    end

    def send_email_finder_file(filepath, domain_column:, first_name_column: nil, last_name_column: nil,
                               middle_name_column: nil, full_name_column: nil, has_header_row: nil)
      raise ArgumentError, 'domain_column is required' if domain_column.nil? || domain_column.to_i < 1
      # One of the two name columns tells the finder what to look for; with
      # neither there is nothing to build a local part from.
      if __blank__(first_name_column) && __blank__(full_name_column)
        raise ArgumentError, 'first_name_column or full_name_column is required'
      end

      params = { domain_column: domain_column }
      params[:has_header_row] = has_header_row ? 'true' : 'false' unless has_header_row.nil?
      params[:first_name_column] = first_name_column unless first_name_column.nil?
      params[:last_name_column] = last_name_column unless last_name_column.nil?
      params[:middle_name_column] = middle_name_column unless middle_name_column.nil?
      params[:full_name_column] = full_name_column unless full_name_column.nil?
      zb_request.bulk_root_post("#{EMAIL_FINDER_BULK_BASE}/sendfile", params, 'multipart/form-data', filepath)
    end

    def email_finder_file_status(file_id)
      zb_request.bulk_root_get("#{EMAIL_FINDER_BULK_BASE}/filestatus", { file_id: file_id })
    end

    def email_finder_file_get(file_id)
      zb_request.bulk_root_getfile("#{EMAIL_FINDER_BULK_BASE}/getfile", { file_id: file_id })
    end

    def email_finder_file_delete(file_id)
      zb_request.bulk_root_get("#{EMAIL_FINDER_BULK_BASE}/deletefile", { file_id: file_id })
    end

    def send_domain_search_file(filepath, domain_column:, has_header_row: nil)
      raise ArgumentError, 'domain_column is required' if domain_column.nil? || domain_column.to_i < 1

      params = { domain_column: domain_column }
      params[:has_header_row] = has_header_row ? 'true' : 'false' unless has_header_row.nil?
      zb_request.bulk_root_post("#{DOMAIN_SEARCH_BULK_BASE}/sendfile", params, 'multipart/form-data', filepath)
    end

    def domain_search_file_status(file_id)
      zb_request.bulk_root_get("#{DOMAIN_SEARCH_BULK_BASE}/filestatus", { file_id: file_id })
    end

    def domain_search_file_get(file_id)
      zb_request.bulk_root_getfile("#{DOMAIN_SEARCH_BULK_BASE}/getfile", { file_id: file_id })
    end

    def domain_search_file_delete(file_id)
      zb_request.bulk_root_get("#{DOMAIN_SEARCH_BULK_BASE}/deletefile", { file_id: file_id })
    end

    def send_list_evaluator_file(filepath, email_address_column:)
      raise ArgumentError, 'email_address_column is required' if email_address_column.nil? || email_address_column.to_i < 1

      params = { email_address_column: email_address_column }
      zb_request.bulk_post('listevaluator/', params, 'multipart/form-data', filepath)
    end

    def get_list_evaluator_result(file_id)
      raise ArgumentError, 'file_id is required' if file_id.nil? || file_id.to_s.strip.empty?

      # The list evaluator has its own base URL, not a path built from the bulk
      # one, and the file id is one path segment, so a slash must stay encoded.
      zb_request.root_request(
        :get,
        Zerobounce.configuration.list_evaluator_root_url,
        "#{ERB::Util.url_encode(file_id.to_s.strip)}/",
        {}
      )
    end

    # Submits a finished evaluation for validation. POST /v2/send-evaluated-file/
    #
    # LIVE: this takes the list evaluator's file_id as a form field, not the
    # file upload the docs describe - an upload is rejected with
    # "file_id: This field is required". It returns a new validation job's
    # file_id, which answers "File cannot be found" for a short while after it
    # is accepted.
    def send_evaluated_file(file_id)
      raise ArgumentError, 'file_id is required' if file_id.nil? || file_id.to_s.strip.empty?

      zb_request.bulk_post('send-evaluated-file/', { file_id: file_id.to_s.strip },
                           'application/x-www-form-urlencoded')
    end

    def add_filter(rule:, target:, value:)
      zb_request.post('filters/add', { rule: rule, target: target, value: value }, 'application/x-www-form-urlencoded')
    end

    def list_filters(use_post: false)
      if use_post
        zb_request.post('filters/list', {}, 'application/x-www-form-urlencoded')
      else
        zb_request.get('filters/list', {})
      end
    end

    def delete_filter(rule:, target:, value:)
      zb_request.post('filters/delete', { rule: rule, target: target, value: value }, 'application/x-www-form-urlencoded')
    end

    def list_s3_files(bucket: nil, search: nil)
      params = {}
      params[:bucket] = bucket unless bucket.nil? || bucket.to_s.empty?
      params[:search] = search unless search.nil? || search.to_s.empty?
      # The S3 listing lives on the bulkapi ROOT, like the jobs below it, not
      # under /v2 - bulk_get would send it to /v2/listS3files, which is a 404.
      zb_request.bulk_root_get('listS3files', params)
    end

    # The same job shape as the four below, so it goes through the same helper:
    # LIVE, the API rejects it without file_name and return_url.
    def validate_s3_file(file_name:, has_header_row: false, **options)
      bulk_root_file_job('validateS3file', file_name, has_header_row, **options)
    end

    def score_s3_file(file_name:, has_header_row: false, **options)
      bulk_root_file_job('scoreS3file', file_name, has_header_row, **options)
    end

    # export_bucket is optional: omit it and the export goes to the bucket in
    # your ZeroBounce settings, the way export_sftp_file's export_path does.
    def export_s3_file(file_id:, export_bucket: nil)
      raise ArgumentError, 'file_id is required' if file_id.nil? || file_id.to_s.strip.empty?

      if !export_bucket.nil? && export_bucket.to_s.strip.empty?
        raise ArgumentError, 'export_bucket is required'
      end

      params = { file_id: file_id }
      params[:export_bucket] = export_bucket unless export_bucket.nil?
      zb_request.bulk_root_form_post('exportS3file', params)
    end

    # The rest of the documented bulk surface.
    #
    # https://www.zerobounce.net/docs/api-integrations/amazon-s3-bulk-api
    # https://www.zerobounce.net/docs/api-integrations/sftp_bulk_api
    #
    # The SFTP server, path and protocol are never sent: they come from your
    # ZeroBounce settings.

    def email_finder_s3_file(file_name, has_header_row, **options)
      bulk_root_file_job('emailFinderS3file', file_name, has_header_row, **options)
    end

    def domain_search_s3_file(file_name, has_header_row, **options)
      bulk_root_file_job('domainSearchS3file', file_name, has_header_row, **options)
    end

    # LIVE: file_name is required here too, although the docs list it as
    # optional for this one endpoint.
    def validate_sftp_file(file_name, has_header_row, **options)
      bulk_root_file_job('validateSFTPfile', file_name, has_header_row, **options)
    end

    def score_sftp_file(file_name, has_header_row, **options)
      bulk_root_file_job('scoreSFTPfile', file_name, has_header_row, **options)
    end

    def email_finder_sftp_file(file_name, has_header_row, **options)
      bulk_root_file_job('emailFinderSFTPfile', file_name, has_header_row, **options)
    end

    def domain_search_sftp_file(file_name, has_header_row, **options)
      bulk_root_file_job('domainSearchSFTPfile', file_name, has_header_row, **options)
    end

    # Note the field name: this endpoint takes export_path, not the
    # export_bucket that export_s3_file sends. Omit it to use your settings.
    def export_sftp_file(file_id:, export_path: nil)
      raise ArgumentError, 'file_id is required' if file_id.nil? || file_id.to_s.strip.empty?

      if !export_path.nil? && export_path.to_s.strip.empty?
        raise ArgumentError, 'export_path is required'
      end

      params = { file_id: file_id }
      params[:export_path] = export_path unless export_path.nil?
      zb_request.bulk_root_form_post('exportSFTPfile', params)
    end

    # Inbox Placement Tester (/api/ipt).
    #
    # Its own host, an Authorization: Bearer header, camelCase JSON bodies, and
    # errors under a "detail" key. Spends the account's inbox-test credits.

    def inbox_placement_providers
      zb_request.ipt_request(:get, 'providers')
    end

    def inbox_placement_test_types
      zb_request.ipt_request(:get, 'test-types')
    end

    # name is capped at 64 characters, testType is 1, 2 or 3, and a testType of
    # 1 (the seed-list test) has nowhere to send from without senderEmail. All
    # three are rejected by the API, so they are caught before a request that
    # would spend inbox-test credits.
    def create_inbox_placement_test(name, **options)
      raise ArgumentError, 'name is required' if name.nil? || name.to_s.strip.empty?
      raise ArgumentError, 'name must be 64 characters or fewer' if name.to_s.strip.length > INBOX_PLACEMENT_NAME_MAX

      if options.key?(:test_type)
        test_type = __inbox_placement_test_type__(options[:test_type])
        if test_type == 1 && __blank__(options[:sender_email])
          raise ArgumentError, 'sender_email is required when test_type is 1'
        end
      end

      body = { 'name' => name }
      {
        test_type: 'testType',
        sender_email: 'senderEmail',
        provider_ids: 'providerIds',
        seed_ids: 'seedIds',
        providers: 'providers',
        webhook_url: 'webhookUrl'
      }.each { |key, wire| body[wire] = options[key] if options.key?(key) }

      zb_request.ipt_request(:post, 'test', {}, json: body)
    end

    def inbox_placement_test(test_id)
      zb_request.ipt_request(:get, "test/#{inbox_placement_test_segment(test_id)}")
    end

    def list_inbox_placement_tests(**options)
      params = {}
      params[:status] = options[:status] if options.key?(:status)
      params[:createdAfter] = options[:created_after] if options.key?(:created_after)
      params[:createdBefore] = options[:created_before] if options.key?(:created_before)
      params[:page] = options[:page] if options.key?(:page)
      if options.key?(:page_size)
        page_size = options[:page_size]
        unless (INBOX_PLACEMENT_PAGE_SIZE_MIN..INBOX_PLACEMENT_PAGE_SIZE_MAX).cover?(page_size.to_i)
          raise ArgumentError,
                "page_size must be between #{INBOX_PLACEMENT_PAGE_SIZE_MIN} and #{INBOX_PLACEMENT_PAGE_SIZE_MAX}"
        end
        # LIVE: the page size parameter is page_size, not the camelCase
        # pageSize the rest of this API uses. page_size=1 paginates; pageSize=1
        # is ignored and the whole list comes back.
        params[:page_size] = page_size
      end
      # LIVE: the listing is GET /tests (plural). /test is the single-test path
      # and answers 'Method "GET" not allowed'.
      zb_request.ipt_request(:get, 'tests', params)
    end

    def delete_inbox_placement_test(test_id)
      zb_request.ipt_request(:delete, "test/#{inbox_placement_test_segment(test_id)}")
    end

    def inbox_placement_webhook
      zb_request.ipt_request(:get, 'webhook')
    end

    def set_inbox_placement_webhook(webhook_url)
      raise ArgumentError, 'webhook_url is required' if webhook_url.nil? || webhook_url.to_s.strip.empty?

      zb_request.ipt_request(:put, 'webhook', {}, json: { 'webhookUrl' => webhook_url })
    end

    private

    # Nil, or a value that is nothing but whitespace. A column index of 0 is
    # not blank: the API accepts it and the caller meant the first column.
    def __blank__(value)
      value.nil? || value.to_s.strip.empty?
    end

    def __inbox_placement_test_type__(value)
      test_type = value.is_a?(Integer) ? value : value.to_s.strip.to_i
      unless INBOX_PLACEMENT_TEST_TYPES.include?(test_type)
        raise ArgumentError, "test_type must be one of #{INBOX_PLACEMENT_TEST_TYPES.join(', ')}"
      end

      test_type
    end

    # POSTs one of the eight documented S3 / SFTP file jobs on the bulkapi root.
    #
    # Booleans go on the wire as the strings 'true'/'false'.
    #
    # LIVE: file_name and return_url are required on every one of these jobs,
    # validateS3file, scoreS3file and validateSFTPfile included, although the
    # docs list both as optional. Without either the API answers "This field is
    # required".
    def bulk_root_file_job(path, file_name, has_header_row, **options)
      raise ArgumentError, 'file_name is required' if __blank__(file_name)
      raise ArgumentError, 'return_url is required' if __blank__(options[:return_url])

      return_url = options[:return_url]

      params = {
        has_header_row: has_header_row ? 'true' : 'false',
        file_name: file_name,
        return_url: return_url
      }
      if options.key?(:remove_duplicates)
        params[:remove_duplicates] = options[:remove_duplicates] ? 'true' : 'false'
      end

      zb_request.bulk_root_form_post(path, params)
    end

    def inbox_placement_test_segment(test_id)
      raise ArgumentError, 'test_id is required' if test_id.nil? || test_id.to_s.strip.empty?

      ERB::Util.url_encode(test_id.to_s.strip)
    end
  end
end
