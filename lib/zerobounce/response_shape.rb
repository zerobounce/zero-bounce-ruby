# frozen_string_literal: true

require 'zerobounce/error'

module Zerobounce
  # The documented JSON type of each field of the typed calls' answers (standard.md
  # section 3: field types are part of the shape). A field the documentation types
  # that arrives with another JSON type is an API error with status 200, never a
  # coerced value; null is accepted for every field that is not required. The
  # answer itself is returned unchanged, still a Hash.
  # rubocop:disable Metrics/ModuleLength
  module ResponseShape
    # fields: name => kind. required: names that must be present and not null.
    # items: array name => the Shape of each item. greylist: a bare
    # {"Message": "..."} answer is a result (validate only).
    Shape = Struct.new(:fields, :required, :items, :greylist)

    # The JSON types a kind allows. A flag is a boolean, or the "true"/"false"
    # string the API also sends. A text_or_array is a string, or an array of strings.
    KINDS = {
      string: [String],
      flag: [TrueClass, FalseClass, String],
      int: [Integer],
      number: [Integer, Float],
      array: [Array],
      text_or_array: [String, Array]
    }.freeze

    def self.shape(fields, required: [], items: {}, greylist: false)
      Shape.new(fields, required, items, greylist)
    end

    VALIDATE = {
      'address' => :string, 'status' => :string, 'sub_status' => :string, 'account' => :string,
      'domain' => :string, 'did_you_mean' => :string, 'domain_age_days' => :string, 'active_in_days' => :string,
      'active_first_seen' => :string, 'free_email' => :flag, 'mx_found' => :flag, 'mx_record' => :string,
      'smtp_provider' => :string, 'catchall_domain' => :flag, 'firstname' => :string, 'lastname' => :string,
      'gender' => :string, 'city' => :string, 'region' => :string, 'zipcode' => :string, 'country' => :string,
      'processed_at' => :string, 'domain_website_exists' => :string, 'domain_registrant_company_name' => :string,
      'message' => :string, 'Message' => :string
    }.freeze

    BATCH_ERROR = { 'error' => :string, 'email_address' => :string }.freeze

    API_USAGE_COUNTERS = %w[
      total status_valid status_invalid status_catch_all status_do_not_mail status_spamtrap status_unknown
      sub_status_toxic sub_status_disposable sub_status_role_based sub_status_possible_trap
      sub_status_global_suppression sub_status_timeout_exceeded sub_status_mail_server_temporary_error
      sub_status_mail_server_did_not_respond sub_status_greylisted sub_status_antispam_system
      sub_status_does_not_accept_mail sub_status_exception_occurred sub_status_failed_syntax_check
      sub_status_mailbox_not_found sub_status_unroutable_ip_address sub_status_possible_typo
      sub_status_no_dns_entries sub_status_role_based_catch_all sub_status_mailbox_quota_exceeded
      sub_status_forcible_disconnect sub_status_failed_smtp_connection sub_status_accept_all
      sub_status_mx_forward sub_status_alternate sub_status_allowed sub_status_blocked sub_status_gold
      sub_status_role_based_accept_all sub_status_leading_period_removed sub_status_alias_address
    ].freeze
    API_USAGE = API_USAGE_COUNTERS.to_h { |name| [name, :int] }.merge('start_date' => :string, 'end_date' => :string)
                                  .freeze

    ACTIVITY = { 'found' => :flag, 'active_in_days' => :string, 'active_first_seen' => :string }.freeze
    SCORE = { 'email' => :string, 'score' => :int }.freeze

    FILE_STATUS = {
      'success' => :flag, 'message' => :text_or_array, 'file_id' => :string, 'file_name' => :string,
      'upload_date' => :string, 'file_status' => :string, 'file_phase_2_status' => :string,
      'complete_percentage' => :string, 'error_reason' => :string, 'return_url' => :string
    }.freeze

    # A file job's send and delete answers.
    FILE_JOB = {
      'success' => :flag, 'message' => :text_or_array, 'file_name' => :string, 'file_id' => :string
    }.freeze

    LIST_EVALUATOR = {
      'file_id' => :string, 'status' => :string, 'progress' => :number, 'invalid_percentage' => :number,
      'catch_all_percentage' => :number, 'activity_data_percentage' => :number, 'abuse' => :flag,
      'do_not_mail' => :flag, 'spam_trap' => :flag, 'total_risky_percentage' => :number,
      'error_message' => :string
    }.freeze

    # guessformat, find_domain and find_email share one endpoint, so one shape covers all three.
    GUESS = {
      'email' => :string, 'domain' => :string, 'company_name' => :string, 'format' => :string,
      'status' => :string, 'sub_status' => :string, 'confidence' => :string, 'email_confidence' => :string,
      'failure_reason' => :string, 'did_you_mean' => :string, 'other_domain_formats' => :array
    }.freeze
    DOMAIN_FORMAT = { 'format' => :string, 'confidence' => :string }.freeze

    VALIDATE_SHAPE = shape(VALIDATE, required: %w[address status], greylist: true)
    FILE_STATUS_SHAPE = shape(FILE_STATUS)
    FILE_JOB_SHAPE = shape(FILE_JOB)
    BATCH_SHAPE = shape(
      { 'email_batch' => :array, 'errors' => :array },
      items: { 'email_batch' => shape(VALIDATE, required: %w[address status]), 'errors' => shape(BATCH_ERROR) }
    )
    GUESS_SHAPE = shape(GUESS, items: { 'other_domain_formats' => shape(DOMAIN_FORMAT) })

    # The shape of each typed answer, by the endpoint path the request uses, or by
    # the name of a call whose path is not fixed (the list evaluator's).
    SHAPES = {
      'validate' => VALIDATE_SHAPE,
      'validatebatch' => BATCH_SHAPE,
      'getapiusage' => shape(API_USAGE),
      'activity' => shape(ACTIVITY),
      'scoring' => shape(SCORE),
      'filestatus' => FILE_STATUS_SHAPE,
      'scoring/filestatus' => FILE_STATUS_SHAPE,
      'email-finder/filestatus' => FILE_STATUS_SHAPE,
      'domain-search/filestatus' => FILE_STATUS_SHAPE,
      'sendfile' => FILE_JOB_SHAPE,
      'scoring/sendfile' => FILE_JOB_SHAPE,
      'email-finder/sendfile' => FILE_JOB_SHAPE,
      'domain-search/sendfile' => FILE_JOB_SHAPE,
      'send-evaluated-file/' => FILE_JOB_SHAPE,
      'deletefile' => FILE_JOB_SHAPE,
      'scoring/deletefile' => FILE_JOB_SHAPE,
      'email-finder/deletefile' => FILE_JOB_SHAPE,
      'domain-search/deletefile' => FILE_JOB_SHAPE,
      'guessformat' => GUESS_SHAPE,
      :list_evaluator => shape(LIST_EVALUATOR)
    }.freeze

    module_function

    # +result+ (a Hash the API sent) checked against the shape of +key+; it is returned
    # unchanged. A key with no shape is not checked.
    def check!(result, key, status = 200)
      shape = SHAPES[key]
      return result if shape.nil?

      check_object!(result, shape, status, '')
      result
    end

    def check_object!(result, shape, status, where)
      check_hash!(result, status, where)
      return if where.empty? && shape.greylist && greylist_answer?(result)

      check_required!(result, shape, status, where)
      shape.fields.each { |name, kind| check_field!(result, [name, kind], shape, status, where) }
      nil
    end

    def check_hash!(result, status, where)
      return if result.is_a?(Hash)

      subject = where.empty? ? 'the response' : where.chomp('.')
      raise unexpected("#{subject} is not an object", status)
    end

    def check_field!(result, (name, kind), shape, status, where)
      value = result[name]
      check_value!(value, kind, "#{where}#{name}", status)
      check_items!(value, shape.items[name], status, "#{where}#{name}") if shape.items.key?(name) && value
    end

    def check_required!(result, shape, status, where)
      missing = shape.required.find { |name| result[name].nil? }
      raise unexpected("#{where}#{missing} is missing", status) if missing
    end

    def check_value!(value, kind, path, status)
      return if value.nil? || allowed?(value, kind)

      raise unexpected("#{path} has the wrong type", status)
    end

    def check_items!(items, item_shape, status, path)
      items.each_with_index { |item, index| check_object!(item, item_shape, status, "#{path}[#{index}].") }
    end

    # validate's greylist answer: a bare message, with no address or status.
    def greylist_answer?(result)
      greylist = result['Message'].is_a?(String) || result['message'].is_a?(String)
      greylist && !result.key?('address') && !result.key?('status')
    end

    def allowed?(value, kind)
      return false unless KINDS.fetch(kind).any? { |type| value.is_a?(type) }
      return value.all?(String) if kind == :text_or_array && value.is_a?(Array)

      true
    end

    def unexpected(problem, status)
      ApiResponseError.new("ZeroBounce returned JSON of an unexpected shape: #{problem}.", status)
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
