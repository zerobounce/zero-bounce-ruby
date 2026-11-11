# frozen_string_literal: true

require 'json'
require 'zerobounce/api_urls'
require 'zerobounce/response_error'
require 'zerobounce/api_key'
require 'zerobounce/error'

# https://github.com/rest-client/rest-client
require 'rest-client'


module Zerobounce

  # Sends the HTTP request.
  class BaseRequest

    protected

    # Strips trailing slashes from root URL without using a regex (avoids ReDoS).
    def self.__root_without_trailing_slashes__(root)
      s = root.to_s
      s = s.chomp('/') while s.end_with?('/')
      s
    end

    # Resolves and validates filepath to prevent path traversal (e.g. ../../etc/passwd).
    # Returns a canonical path only if the file is under the current directory and is a regular file.
    def self.__safe_file_path__(filepath)
      raise ArgumentError, 'File path is required' if filepath.nil? || filepath.to_s.empty?
      filepath = filepath.to_s
      expanded = File.expand_path(filepath)
      base = File.realpath(Dir.pwd)
      base_with_sep = base + File::SEPARATOR
      unless expanded == base || expanded.start_with?(base_with_sep)
        raise ArgumentError, 'File path must be under the current directory'
      end
      canonical = File.realpath(expanded)
      unless canonical == base || canonical.start_with?(base_with_sep)
        raise ArgumentError, 'File path must be under the current directory'
      end
      unless File.file?(canonical)
        raise ArgumentError, 'File path must point to a regular file'
      end
      canonical
    end

    def self.__require_https__(url)
      unless url.to_s.downcase.start_with?('https://')
        raise ArgumentError, 'API URL must be an https:// URL'
      end
      url
    end

    # Removes the API key from error text. The key the request actually used
    # (a Zerobounce::Client's or with_api_key's, which is thread-local) is
    # redacted as well as the global one, in its raw and URL-encoded forms.
    def self.__redact_api_key__(message)
      text = message.to_s
      [current_api_key, Zerobounce.config.apikey].uniq.each do |key|
        next if key.nil? || key.to_s.strip.empty?

        [key.to_s, URI.encode_www_form_component(key.to_s)].uniq.each do |form|
          text = text.gsub(form, '***')
        end
      end
      text
    end

    def self.current_api_key
      key = Thread.current[:zerobounce_api_key]
      key.nil? ? Zerobounce.config.apikey : key
    end

    # The key for this request, or an error before anything is sent. A key with
    # surrounding whitespace or control characters (one read from a file with
    # its newline) would go out as it is and fail, and the HTTP library could
    # quote it unredacted.
    def self.__checked_api_key__
      api_key = current_api_key
      raise ('API key must be assigned') if api_key.nil? || api_key.to_s.strip.empty?

      ApiKey.check!(api_key)
    end

    # The message for an HTTP error status.
    def self.__http_error_message__(error)
      code = error.http_code.to_i
      # max_redirects is 0, so a 3xx is never followed; say so rather than
      # reporting its (usually empty) body as an "Empty response".
      if code.between?(300, 399)
        return "ZeroBounce answered with a redirect (HTTP #{code}), which is not followed"
      end

      ResponseError.message_from(error.response)
    end

    def self.__execute_request__(**kwargs)
      kwargs[:max_redirects] = 0
      user_agent = Zerobounce.config.headers && Zerobounce.config.headers[:user_agent]
      kwargs[:headers] = (kwargs[:headers] || {}).merge(user_agent: user_agent) if user_agent
      RestClient::Request.execute(**kwargs)
    rescue RestClient::ExceptionWithResponse => e
      # Re-raised as the same RestClient class (RestClient::NotFound and so
      # on), so `rescue RestClient::...` and #http_code keep working as they
      # did up to 2.1.8. Only the message changes: the API's short error text,
      # with the key redacted.
      e.message = __redact_api_key__(__http_error_message__(e))
      raise e
    rescue RestClient::Exception => e
      e.message = __redact_api_key__(e.message)
      raise e
    rescue StandardError => e
      # Same class and backtrace, redacted message. cause: nil, because the
      # original (unredacted) error would otherwise ride along as #cause and
      # be printed by #full_message.
      raise e.exception(__redact_api_key__(e.message)), cause: nil
    end

    def self._get(root, path, params, content_type='application/json')

      # puts path
      # puts Zerobounce.config.apikey

      api_key = __checked_api_key__

      params[:api_key] = api_key
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)

      response = __execute_request__(method: :get, url: url, timeout: 120, headers: { params: params })
      return response
    end

    def self._post(root, path, params, content_type='application/json', filepath=nil)

      api_key = __checked_api_key__

      params[:api_key] = api_key
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)
      response = nil

      if filepath or content_type == 'multipart/form-data'
        params.each do |key, value|
          params[key] = value ? 'true' : 'false' if value == true || value == false
        end
        params[:file] = File.new(Zerobounce::BaseRequest.__safe_file_path__(filepath), 'rb')
        params[:multipart] = true
        response = __execute_request__(method: :post, url: url, payload: params, timeout: 120)

      elsif content_type == 'application/json'
        response = __execute_request__(
          method: :post,
          url: url,
          payload: params.to_json,
          timeout: 120,
          headers: { content_type: :json, accept: :json }
        )
      elsif content_type == 'application/x-www-form-urlencoded'
        response = __execute_request__(method: :post, url: url, payload: params, timeout: 120)
      else
        # this shouldn't happen
        raise Error.new('Unknown content type specified in request.'\
          ' Must be either multipart/form-data or application/json.')
      end
      return response
    end

    # Sends a request with an explicit method and an optional form or JSON body.
    #
    # The endpoints ported from the Python SDK need shapes _get and _post cannot
    # express: a form-encoded POST on an arbitrary base URL, and the Inbox
    # Placement Tester's PUT and DELETE with the API key on the query string.
    # +bearer+ sends the key in an Authorization header instead of a query
    # parameter, which the Inbox Placement Tester requires and which keeps the
    # key out of request logs.
    def self.__execute_with_method__(method, url, params, form: nil, json: nil, bearer: false)
      api_key = __checked_api_key__

      params = (params || {}).dup
      extra = {}
      if bearer
        extra[:authorization] = "Bearer #{api_key}"
      else
        params = params.merge(api_key: api_key)
      end
      Zerobounce::BaseRequest.__require_https__(url)

      options = { method: method, url: url, timeout: 120 }
      if form
        options[:payload] = form
        options[:headers] = extra.merge(params: params, content_type: 'application/x-www-form-urlencoded')
      elsif json
        options[:payload] = json.to_json
        options[:headers] = extra.merge(params: params, content_type: :json, accept: :json)
      else
        options[:headers] = extra.merge(params: params)
      end

      __execute_request__(**options)
    end

    # A GET or form-encoded POST against an arbitrary base URL, for the list
    # evaluator, which has its own host.
    def self.root_request(method, root, path, params, form: nil)
      url = "#{__root_without_trailing_slashes__(root)}/#{path.to_s.sub(%r{\A/}, '')}"
      __parse_json_response__(__execute_with_method__(method, url, params, form: form))
    end

    # One Inbox Placement Tester call.
    def self.ipt_request(method, path, params = {}, json: nil)
      root = Zerobounce.configuration.inbox_placement_root_url
      url = "#{__root_without_trailing_slashes__(root)}/#{path.to_s.sub(%r{\A/}, '')}"
      # LIVE: the Inbox Placement Tester authenticates with a Bearer header.
      # Sent as an api_key parameter the request is rejected as unauthorized.
      response = __execute_with_method__(method, url, params, json: json, bearer: true)
      return nil if response.body.to_s.strip.empty?

      __parse_json_response__(response)
    end

    # Whether a Content-Type names a JSON body.
    #
    # The API types most responses 'application/json' but some
    # 'application/json; charset=utf-8'. Compared with ==, the second kind
    # skipped JSON parsing entirely, so an {"error": ...} payload came back as
    # a raw String and read as a success. Only the media type decides; the
    # parameters after the semicolon are ignored.
    def self.__json_content_type__(content_type)
      media_type = content_type.to_s.split(';', 2).first.to_s.strip.downcase
      media_type == 'application/json' || media_type.end_with?('+json')
    end

    # The root for the S3 and SFTP/FTP jobs: the bulkapi host WITHOUT /v2.
    #
    # +bulk_root_url+ (ZEROBOUNCE_BULK_ROOT_URL) wins when it is set, so these
    # endpoints can be pointed at a mock server on their own. Left unset it is
    # derived from +bulk_api_root_url+ with the /v2 stripped, so overriding
    # that one alone still moves these endpoints with it.
    def self.bulk_api_root_without_v2
      configured = Zerobounce.configuration.bulk_root_url.to_s.strip
      return __root_without_trailing_slashes__(configured) unless configured.empty?

      # Trailing slashes first, so ".../v2//" loses its /v2 as well.
      derived = __root_without_trailing_slashes__(Zerobounce.configuration.bulk_api_root_url).delete_suffix('/v2')
      derived = ApiUrls::BULK_ROOT_URL if derived.strip.empty?
      __root_without_trailing_slashes__(derived)
    end

    # Whether a "success" field means failure. The API sends it as a JSON
    # false, "false" or "False" depending on the endpoint.
    def self.__success_means_failure__(value)
      return !value if value == true || value == false

      value.is_a?(String) && value.strip.casecmp('false').zero?
    end

    # LIVE: {"success": false} on an HTTP 200 is a failure, not a result. The
    # API answers an unknown bulk file id that way. Applied to the main API
    # and the bulk API alike.
    def self.__raise_if_success_false__(response, parsed)
      return unless parsed.is_a?(Hash) && parsed.key?('success') && __success_means_failure__(parsed['success'])

      raise ApiResponseError.new(
        ResponseError.message_from_parts(response.code, response.headers[:content_type].to_s, response.body.to_s),
        response.code
      )
    end

    # A value that reads as an error: a non-blank String.
    def self.__error_text__(value)
      value.is_a?(String) && !value.strip.empty?
    end

    # An "error" value that means failure: anything but nil or a blank String.
    def self.__error_value__(value)
      !value.nil? && !(value.is_a?(String) && value.strip.empty?)
    end

    # The keys a message-only body is made of.
    MESSAGE_KEYS = %w[error message error_message Message Error detail].freeze

    # A body made only of message keys (no "success"), for the calls whose
    # result is never a bare message.
    def self.__raise_if_message_only__(response, parsed)
      return if parsed.empty? || parsed.key?('success')
      return unless parsed.keys.all? { |key| MESSAGE_KEYS.include?(key) }

      text = MESSAGE_KEYS.map { |key| parsed[key] }.find { |value| __error_text__(value) }
      raise ApiResponseError.new(ResponseError.strip_prefix(text), response.code) if text
    end

    # A dead or invalid key on an HTTP 200: no "success" field and a non-empty
    # "Error" (LIVE: the filters spell it so) or "error_message".
    def self.__raise_if_bare_error__(response, parsed)
      return if parsed.key?('success')

      %w[Error error_message].each do |key|
        next unless __error_text__(parsed[key])

        raise ApiResponseError.new(ResponseError.strip_prefix(parsed[key]), response.code)
      end
    end

    def self.__parse_json_response__(response)
      body = response.body.to_s
      content_type = (response.headers[:content_type] || '').to_s
      code = response.code
      if ResponseError.html?(body, content_type) || body.strip.empty?
        raise ApiResponseError.new(ResponseError.message_from_parts(code, content_type, body), code)
      end
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        raise ApiResponseError.new('ZeroBounce returned a response that is not valid JSON.', code)
      end
      return parsed unless parsed.is_a?(Hash)

      __raise_if_success_false__(response, parsed)

      raise ApiResponseError.new(ResponseError.strip_prefix(parsed['error']), code) if __error_value__(parsed['error'])
      # The Inbox Placement Tester is a Django REST framework app and reports
      # its errors under "detail" rather than "error"/"message".
      if __error_value__(parsed['detail'])
        raise ApiResponseError.new(ResponseError.strip_prefix(parsed['detail']), code)
      end
      __raise_if_bare_error__(response, parsed)
      if parsed.key?('errors') && parsed['errors'].is_a?(Array) && !parsed['errors'].empty?
        raise ApiResponseError.new(ResponseError.strip_prefix(parsed['errors'][0]['error']), code)
      end
      parsed
    end

  end
end