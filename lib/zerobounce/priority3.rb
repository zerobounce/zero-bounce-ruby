# frozen_string_literal: true

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
      zb_request.bulk_get("listevaluator/#{file_id}/", {})
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
  end
end
