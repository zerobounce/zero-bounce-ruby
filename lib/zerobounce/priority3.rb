# frozen_string_literal: true

require 'erb'

module Zerobounce
  module Priority3
    EMAIL_FINDER_BULK_BASE = 'email-finder'
    DOMAIN_SEARCH_BULK_BASE = 'domain-search'

    def zb_request
      Zerobounce.class_variable_get(:@@request)
    end

    def send_email_finder_file(filepath, domain_column:, first_name_column: nil, last_name_column: nil,
                               middle_name_column: nil, full_name_column: nil, has_header_row: nil)
      raise ArgumentError, 'domain_column is required' if domain_column.nil? || domain_column.to_i < 1

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

    def send_evaluated_file(filepath)
      zb_request.bulk_post('send-evaluated-file/', {}, 'multipart/form-data', filepath)
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
      zb_request.bulk_get('listS3files', params)
    end

    def validate_s3_file(file_name:, **options)
      raise ArgumentError, 'file_name is required' if file_name.nil? || file_name.to_s.empty?

      params = { file_name: file_name }
      options.each do |key, value|
        next if value.nil?
        params[key] = value.is_a?(TrueClass) || value.is_a?(FalseClass) ? (value ? 'true' : 'false') : value
      end
      zb_request.bulk_root_form_post('validateS3file', params)
    end

    def score_s3_file(file_name:, **options)
      raise ArgumentError, 'file_name is required' if file_name.nil? || file_name.to_s.empty?

      params = { file_name: file_name }
      options.each do |key, value|
        next if value.nil?
        params[key] = value.is_a?(TrueClass) || value.is_a?(FalseClass) ? (value ? 'true' : 'false') : value
      end
      zb_request.bulk_root_form_post('scoreS3file', params)
    end

    def export_s3_file(file_id:, export_bucket:)
      raise ArgumentError, 'file_id is required' if file_id.nil? || file_id.to_s.empty?
      raise ArgumentError, 'export_bucket is required' if export_bucket.nil? || export_bucket.to_s.empty?

      zb_request.bulk_root_form_post('exportS3file', { file_id: file_id, export_bucket: export_bucket })
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

    # This is the one job whose file_name the docs list as optional: pass nil to
    # use the input bucket from your ZeroBounce settings.
    def validate_sftp_file(file_name, has_header_row, **options)
      bulk_root_file_job('validateSFTPfile', file_name, has_header_row,
                         file_name_required: false, **options)
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
    # Its own host, the API key on the query string, camelCase JSON bodies, and
    # errors under a "detail" key. Spends the account's inbox-test credits.

    def inbox_placement_providers
      zb_request.ipt_request(:get, 'providers')
    end

    def inbox_placement_test_types
      zb_request.ipt_request(:get, 'test-types')
    end

    def create_inbox_placement_test(name, **options)
      raise ArgumentError, 'name is required' if name.nil? || name.to_s.strip.empty?

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
      params[:page] = options[:page] if options.key?(:page)
      params[:pageSize] = options[:page_size] if options.key?(:page_size)
      zb_request.ipt_request(:get, 'test', params)
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

    # POSTs one of the six documented S3 / SFTP file jobs on the bulkapi root.
    #
    # Booleans go on the wire as the strings 'true'/'false', and an option that
    # was not given is not sent at all.
    def bulk_root_file_job(path, file_name, has_header_row, file_name_required: true, **options)
      blank = !file_name.nil? && file_name.to_s.strip.empty?
      if (file_name.nil? && file_name_required) || blank
        raise ArgumentError, 'file_name is required'
      end

      params = { has_header_row: has_header_row ? 'true' : 'false' }
      params[:file_name] = file_name unless file_name.nil?
      if options.key?(:remove_duplicates)
        params[:remove_duplicates] = options[:remove_duplicates] ? 'true' : 'false'
      end
      params[:return_url] = options[:return_url] if options.key?(:return_url)

      zb_request.bulk_root_form_post(path, params)
    end

    def inbox_placement_test_segment(test_id)
      raise ArgumentError, 'test_id is required' if test_id.nil? || test_id.to_s.strip.empty?

      ERB::Util.url_encode(test_id.to_s.strip)
    end
  end
end
