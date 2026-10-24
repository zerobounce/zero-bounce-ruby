# frozen_string_literal: true

require 'date'
require 'erb'
require 'json'
require 'rest-client'

require 'zerobounce/error'
require 'zerobounce/response_error'

module Zerobounce
  # Client for the ZeroBounce Warmup API
  # (https://www.zerobounce.net/docs/warmup-api).
  #
  # The Warmup API is separate from the email validation API: its own host, its
  # own team-scoped key, and an "API-Key" header instead of an api_key
  # parameter. Use Zerobounce::Warmup with a Warmup API key; the Zerobounce
  # module stays for the validation API key.
  #
  #   warmup = Zerobounce::Warmup.new('<YOUR_WARMUP_API_KEY>')
  #   warmup.list_sending_accounts
  #
  # A documented empty success (204, or an empty 200) comes back as nil. A
  # payload that is not a JSON object - /seeds is an array, /seed-count a bare
  # number - comes back as the parsed value itself.
  class Warmup
    DEFAULT_BASE_URL = 'https://warmup-api.zerobounce.net'
    BASE_PATH = '/api/v1/warmup'

    ONBOARDING_MODELS = %w[self_managed zb_managed].freeze
    EMAIL_TYPES = %w[transactional newsletter marketing].freeze

    # Required by the schema but always replaced with the key's own team.
    ANY_TEAM_ID = 1

    # @param api_key [String] your Warmup API key, sent in the API-Key header
    # @param base_url [String] defaults to https://warmup-api.zerobounce.net
    def initialize(api_key, base_url = DEFAULT_BASE_URL)
      raise ArgumentError, 'api_key is required' if api_key.nil? || api_key.to_s.strip.empty?

      # A key with surrounding whitespace or control characters would be
      # quoted, unredacted, in the HTTP library's own error.
      if api_key != api_key.strip || api_key.match?(/[\u0000-\u001f\u007f]/)
        raise ArgumentError, 'api_key has surrounding whitespace or control characters'
      end
      unless base_url.to_s.downcase.start_with?('https://')
        raise ArgumentError, 'base_url must be an https:// URL'
      end

      @api_key = api_key
      root = base_url.to_s
      root = root.chomp('/') while root.end_with?('/')
      @root = "#{root}#{BASE_PATH}"
    end

    # -- sending accounts ---------------------------------------------------

    # Every sending account of the key's team. GET /sending-accounts
    def list_sending_accounts
      get('/sending-accounts')
    end

    # One sending account. GET /sending-account
    def get_sending_account(from_address)
      require_value(from_address, 'from_address')
      get('/sending-account', from_address: from_address)
    end

    # Adds a from-address to warmup. POST /sending-accounts
    #
    # +self_managed+ runs your own mailbox and needs +engagement_rule_id+ 0-4.
    # +zb_managed+ has ZeroBounce provision it and takes +email_content+ and
    # +managed_sending+; a 200 means accepted, and the mailbox is provisioned
    # afterwards.
    def add_sending_account(from_address, onboarding_model, **options)
      require_value(from_address, 'from_address')
      unless ONBOARDING_MODELS.include?(onboarding_model.to_s)
        raise ArgumentError, 'onboarding_model must be self_managed or zb_managed'
      end

      body = { 'from_address' => from_address, 'onboarding_model' => onboarding_model.to_s }
      if onboarding_model.to_s == 'self_managed'
        rule = options[:engagement_rule_id]
        raise ArgumentError, 'engagement_rule_id is required for self_managed' if rule.nil?

        body['engagement_rule_id'] = in_range(rule, 0, 4, 'engagement_rule_id')
        if options.key?(:email_content) || options.key?(:managed_sending)
          raise ArgumentError, 'email_content and managed_sending are for zb_managed'
        end
      end
      body['ignore_conflict'] = !options[:ignore_conflict].nil? && options[:ignore_conflict] ? true : false if
        options.key?(:ignore_conflict)
      body['email_content'] = email_content_body(options[:email_content]) if options.key?(:email_content)
      body['managed_sending'] = managed_sending_body(options[:managed_sending]) if options.key?(:managed_sending)

      json_request(:post, '/sending-accounts', {}, body)
    end

    # Changes an account's engagement rule, status and auto-enable flag.
    # PUT /sending-accounts. +status_id+ is 0 to 8 (4 Paused, 5 Disabled).
    def update_sending_account(from_address, engagement_rule_id, status_id, auto_enable)
      require_value(from_address, 'from_address')
      unless [true, false].include?(auto_enable)
        raise ArgumentError, 'auto_enable must be true or false'
      end

      json_request(:put, '/sending-accounts', {},
                   { 'team_id' => ANY_TEAM_ID,
                     'from_address' => from_address,
                     'engagement_rule_id' => in_range(engagement_rule_id, 0, 4, 'engagement_rule_id'),
                     'status_id' => in_range(status_id, 0, 8, 'status_id'),
                     'auto_enable' => auto_enable })
    end

    # Removes a sending account. DELETE /sending-accounts. Destructive and final.
    def delete_sending_account(from_address)
      require_value(from_address, 'from_address')
      json_request(:delete, '/sending-accounts', { from_address: from_address })
    end

    # Moves an account and its history to a new from-address.
    # PUT /smtp-credentials - despite the path, no SMTP credentials are stored.
    def change_from_address(old_from_address, new_from_address)
      require_value(old_from_address, 'old_from_address')
      require_value(new_from_address, 'new_from_address')
      json_request(:put, '/smtp-credentials', {},
                   { 'team_id' => ANY_TEAM_ID,
                     'old_from_address' => old_from_address,
                     'new_from_address' => new_from_address })
    end

    # Registered from-addresses. GET /from-addresses
    #
    # +search_from+ takes letters, digits and . - _ @ + only. +offset+ and
    # +limit+ go on the wire as strings.
    def list_from_addresses(search_from: nil, offset: nil, limit: nil)
      params = {}
      unless search_from.nil?
        unless search_from.to_s.match?(/\A[A-Za-z0-9.\-_@+]*\z/)
          raise ArgumentError, 'search_from takes letters, digits and . - _ @ + only'
        end

        params[:search_from] = search_from
      end
      { offset: offset, limit: limit }.each do |name, value|
        next if value.nil?
        raise ArgumentError, "#{name} must be a non-negative integer" unless value.is_a?(Integer) && value >= 0

        params[name] = value.to_s
      end
      get('/from-addresses', **params)
    end

    # -- engagement rules ---------------------------------------------------

    # -1 Custom, 0 Default, 1 Slow Pace, 2 Repair, 3 Boost, 4 Protect.
    def engagement_rules
      get('/engagement-rules')
    end

    # Sets a standard rule (0 to 4) on an address. PUT /engagement-rule
    def set_engagement_rule(c_from, rule_id)
      require_value(c_from, 'c_from')
      json_request(:put, '/engagement-rule', { c_from: c_from },
                   { 'rule_id' => in_range(rule_id, 0, 4, 'rule_id') })
    end

    # An address's custom rule, with can_update and remaining_seconds.
    def custom_engagement(c_from)
      require_value(c_from, 'c_from')
      segment = c_from.to_s.strip
      raise ArgumentError, 'c_from is invalid' if ['.', '..'].include?(segment)

      get("/custom-engagement/#{ERB::Util.url_encode(segment)}")
    end

    # Creates a custom rule. Starts a 7 day cooldown on updates.
    def create_custom_engagement(c_from, reply_pct, important_pct, click_pct)
      json_request(:post, '/custom-engagement', {},
                   engagement_body(c_from, reply_pct, important_pct, click_pct))
    end

    # Updates a custom rule. During the 7 day cooldown the API answers 429.
    def update_custom_engagement(c_from, reply_pct, important_pct, click_pct)
      json_request(:put, '/custom-engagement', {},
                   engagement_body(c_from, reply_pct, important_pct, click_pct))
    end

    # Deletes a custom rule and falls back to standard rule 1-4.
    def delete_custom_engagement(c_from, engagement_rule_id)
      require_value(c_from, 'c_from')
      json_request(:delete, '/custom-engagement', {},
                   { 'c_from' => c_from,
                     'engagement_rule_id' => in_range(engagement_rule_id, 1, 4, 'engagement_rule_id') })
    end

    # -- statistics, seeds and utilities ------------------------------------

    # The seed list. GET /seeds
    def seeds
      get('/seeds')
    end

    # The seed list as CSV (columns seed,provider). GET /seeds/download
    def download_seeds
      csv('/seeds/download')
    end

    # Number of seeds. GET /seed-count
    def seed_count
      get('/seed-count')
    end

    # Today's warmup progress. GET /progress-today
    def progress_today
      get('/progress-today')
    end

    # Messages sent today. GET /sent-today
    def sent_today
      get('/sent-today')
    end

    # Current daily volume. GET /emails-per-day
    def emails_per_day
      get('/emails-per-day')
    end

    # Statistics for an address. An address with no history returns zeros.
    def statistics(from_address)
      require_value(from_address, 'from_address')
      get('/statistics', from_address: from_address)
    end

    # Daily statistics between two dates, inclusive. GET /statistics-per-day
    def statistics_per_day(from_address, start_date, end_date)
      require_value(from_address, 'from_address')
      first = api_date(start_date, 'start_date')
      last = api_date(end_date, 'end_date')
      raise ArgumentError, 'start_date is later than end_date' if first > last

      get('/statistics-per-day', from_address: from_address, start_date: first, end_date: last)
    end

    # Detailed statistics for an address. GET /statistics-detailed
    def statistics_detailed(c_from)
      require_value(c_from, 'c_from')
      get('/statistics-detailed', c_from: c_from)
    end

    # An address's statistics as CSV. GET /statistics/download
    def download_statistics(c_from)
      require_value(c_from, 'c_from')
      csv('/statistics/download', c_from: c_from)
    end

    # Statistics for one from-address. GET /from-address-statistics
    def from_address_statistics(from_address)
      require_value(from_address, 'from_address')
      get('/from-address-statistics', from_address: from_address)
    end

    # SPF, DKIM and DMARC status of a from-address's domain.
    # GET /check-domain-dmarc
    #
    # LIVE: pass an EMAIL ADDRESS. The live API answers "Please provide a valid
    # email address" for a bare domain, although the docs describe a domain.
    def check_domain_dmarc(from_address, dkim_selector: nil)
      require_value(from_address, 'from_address')
      unless from_address.to_s.include?('@')
        raise ArgumentError, 'from_address must be an email address, e.g. sender@example.com'
      end

      params = { from_address: from_address }
      unless dkim_selector.nil?
        require_value(dkim_selector, 'dkim_selector')
        params[:dkim_selector] = dkim_selector
      end
      get('/check-domain-dmarc', **params)
    end

    # Checks that SMTP credentials connect and hand off a message.
    # POST /test-smtp-configuration
    #
    # Nothing is stored, and the test message goes to a ZeroBounce test
    # recipient, not +from_address+.
    #
    # LIVE: the API answers any failed SMTP login with HTTP 500. That is an API
    # bug. The username and password are masked in every error from this method.
    def test_smtp_configuration(from_address, username, password, server, port)
      require_value(from_address, 'from_address')
      require_value(username, 'username')
      require_value(password, 'password')
      require_value(server, 'server')
      raise ArgumentError, 'port must be 1 to 65535' unless port.is_a?(Integer) && port.between?(1, 65_535)

      json_request(:post, '/test-smtp-configuration', {},
                   { 'from_address' => from_address,
                     'username' => username,
                     'password' => password,
                     'server' => server,
                     'port' => port },
                   secrets: [password, username])
    end

    private

    attr_reader :api_key, :root

    # -- argument checks ----------------------------------------------------

    def require_value(value, name)
      raise ArgumentError, "#{name} is required" if value.nil? || value.to_s.strip.empty?

      value
    end

    def in_range(value, low, high, name)
      unless value.is_a?(Integer) && value.between?(low, high)
        raise ArgumentError, "#{name} must be #{low} to #{high}"
      end

      value
    end

    # A date for the API: a Date/Time or a YYYY-MM-DD string.
    def api_date(value, name)
      return value.strftime('%Y-%m-%d') if value.respond_to?(:strftime)
      return value if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      raise ArgumentError, "#{name} must be YYYY-MM-DD"
    end

    def engagement_body(c_from, reply_pct, important_pct, click_pct)
      require_value(c_from, 'c_from')
      in_range(reply_pct, 5, 45, 'reply_pct')
      in_range(important_pct, 5, 40, 'important_pct')
      in_range(click_pct, 0, 70, 'click_pct')
      if click_pct > important_pct * 1.75
        raise ArgumentError, 'click_pct must be at most important_pct x 1.75'
      end

      { 'c_from' => c_from, 'reply_pct' => reply_pct,
        'important_pct' => important_pct, 'click_pct' => click_pct }
    end

    def email_content_body(content)
      raise ArgumentError, 'email_content must be a Hash' unless content.is_a?(Hash)

      body = {}
      types = content[:types_of_emails] || content['types_of_emails']
      unless types.nil?
        Array(types).each do |kind|
          unless EMAIL_TYPES.include?(kind.to_s)
            raise ArgumentError, 'types_of_emails must be transactional, newsletter and/or marketing'
          end
        end
        body['types_of_emails'] = Array(types).map(&:to_s)
      end
      %i[industry company_name website].each do |key|
        value = content[key] || content[key.to_s]
        body[key.to_s] = value unless value.nil?
      end
      body
    end

    def managed_sending_body(sending)
      raise ArgumentError, 'managed_sending must be a Hash' unless sending.is_a?(Hash)

      body = {}
      offset = sending[:timezone_offset] || sending['timezone_offset']
      body['timezone_offset'] = in_range(offset, -11, 14, 'timezone_offset') unless offset.nil?
      start = sending[:warmup_start_date] || sending['warmup_start_date']
      body['warmup_start_date'] = api_date(start, 'warmup_start_date') unless start.nil?
      limit = sending[:daily_limit] || sending['daily_limit']
      body['daily_limit'] = limit unless limit.nil?
      body
    end

    # -- transport ----------------------------------------------------------

    # Replaces every form of a secret in a message with ***.
    def redact(text, secrets = [])
      value = text.to_s
      ([api_key] + secrets).each do |secret|
        next if secret.nil? || secret.to_s.empty?

        value = value.gsub(secret.to_s, '***').gsub(ERB::Util.url_encode(secret.to_s), '***')
      end
      value
    end

    def get(path, **params)
      json_request(:get, path, params)
    end

    def send_request(method, path, params, body, secrets)
      url = "#{root}#{path}"
      options = {
        method: method,
        url: url,
        timeout: 120,
        max_redirects: 0,
        headers: { 'API-Key' => api_key, accept: :json, params: params }
      }
      if body
        options[:payload] = body.to_json
        options[:headers][:content_type] = :json
      end
      RestClient::Request.execute(**options)
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
      status = response.respond_to?(:code) ? response.code : 0
      if status >= 300 && status < 400
        raise ApiResponseError.new(
          'ZeroBounce returned a redirect, which this client does not follow.', status
        )
      end
      raise ApiResponseError.new(
        redact(
          ResponseError.message_from_parts(
            status, (response.headers[:content_type] || '').to_s, response.body.to_s
          ), secrets
        ), status
      )
    rescue ApiResponseError
      raise
    rescue StandardError => e
      # Rebuilt rather than re-raised: the original holds the URL and headers.
      raise e.class, redact(e.message, secrets)
    end

    # The JSON payload of a success, or nil for the documented empty successes
    # (204, and an empty 200).
    def json_request(method, path, params = {}, body = nil, secrets: [])
      response = send_request(method, path, params, body, secrets)
      text = response.body.to_s
      return nil if response.code == 204 || text.strip.empty?

      begin
        JSON.parse(text, quirks_mode: true)
      rescue JSON::ParserError
        raise ApiResponseError.new(
          redact(
            ResponseError.message_from_parts(
              response.code, (response.headers[:content_type] || '').to_s, text
            ), secrets
          ), response.code
        )
      end
    end

    # A CSV download, returned as text.
    def csv(path, **params)
      response = send_request(:get, path, params, nil, [])
      text = response.body.to_s
      content_type = (response.headers[:content_type] || '').to_s
      if text.strip.empty? || content_type.downcase.include?('application/json')
        raise ApiResponseError.new(
          redact(ResponseError.message_from_parts(response.code, content_type, text)),
          response.code
        )
      end
      text
    end
  end
end
