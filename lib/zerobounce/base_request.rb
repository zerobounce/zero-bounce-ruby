# frozen_string_literal: true

require 'json'
require 'stringio'
require 'zerobounce/api_urls'
require 'zerobounce/response_error'
require 'zerobounce/api_key'
require 'zerobounce/strict_json'
require 'zerobounce/error'
require 'zerobounce/response_shape'

require 'zerobounce/http_transport'

module Zerobounce

  # Sends the HTTP request.
  class BaseRequest
    # A file part the SDK builds from the caller's IO or String (the
    # *_send_stream methods). It is content, not a path, so the check that
    # keeps caller-supplied paths under the current directory does not apply
    # to it, and nothing is written to disk. It is sent as a file part named
    # +original_filename+.
    class Upload
      attr_reader :original_filename

      def initialize(content, file_name)
        @io = StringIO.new(content.to_s.b)
        @original_filename = File.basename(file_name.to_s)
      end

      def content
        @io.string
      end

      def content_type
        'text/csv'
      end

      def close
        @io.close
      end
    end

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
      ApiUrls.check!(url, 'API URL')
    end

    # Removes the API key from error text. The key the request actually used
    # (a Zerobounce::Client's or with_api_key's, which is thread-local) is
    # redacted as well as the global one, in its raw, URL-encoded and
    # JSON-escaped forms.
    def self.__redact_api_key__(message)
      ApiKey.redact(message, [current_api_key, Zerobounce.config.apikey].uniq)
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
    def self.__http_error_message__(response)
      code = response.code.to_i
      # Redirects are never followed; say so rather than reporting the (usually
      # empty) body as an "Empty response".
      if code.between?(300, 399)
        return "ZeroBounce answered with a redirect (HTTP #{code}), which is not followed"
      end

      ResponseError.message_from(response)
    end

    # The content of a stream the caller passed to a *_send_stream method.
    # A read that fails is the SDK's error, and nothing is sent.
    def self.read_stream(io)
      return io.to_s unless io.respond_to?(:read)

      io.read.to_s
    rescue StandardError => e
      raise ApiResponseError.new(
        __redact_api_key__("Could not read the upload stream (#{e.class}): #{e.message}"), 0
      ), cause: nil
    end

    # Sends one request. An HTTP error status (4xx, 5xx, and a 3xx, which is
    # never followed) raises ApiResponseError with that status; a transport
    # failure raises it with status 0. Messages are redacted of the API key.
    def self.__execute_request__(method:, url:, query: nil, headers: {}, body: nil)
      # Re-checked on every send, whichever entry point built the URL; outside
      # the rescue below, so it is the caller's ArgumentError.
      __require_https__(url)
      __send_checked__(method: method, url: url, query: query, headers: headers, body: body)
    end

    def self.__send_checked__(method:, url:, query:, headers:, body:)
      user_agent = Zerobounce.config.headers && Zerobounce.config.headers[:user_agent]
      headers = headers.merge(user_agent: user_agent) if user_agent
      response = HttpTransport.execute(
        method: method, url: url, query: query, headers: headers, body: body,
        redact: ->(text) { __redact_api_key__(text) }
      )
      if response.code >= 300
        raise ApiResponseError.new(__redact_api_key__(__http_error_message__(response)), response.code), cause: nil
      end

      response
    rescue ApiResponseError
      raise
    rescue StandardError => e
      # cause: nil, because the original (unredacted) error would otherwise
      # ride along as #cause and be printed by #full_message.
      raise HttpTransport.failure(e, ->(text) { __redact_api_key__(text) }), cause: nil
    end

    def self._get(root, path, params, content_type='application/json')

      # puts path
      # puts Zerobounce.config.apikey

      api_key = __checked_api_key__

      params[:api_key] = api_key
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)

      response = __execute_request__(method: :get, url: url, query: params)
      return response
    end

    # The file part of a multipart upload: the content is read up front, so a
    # file that cannot be read is an error before anything is sent.
    def self.__file_part__(filepath)
      if filepath.is_a?(Upload)
        return { name: 'file', filename: filepath.original_filename, content: filepath.content,
                 content_type: filepath.content_type }
      end

      path = __safe_file_path__(filepath)
      begin
        content = File.binread(path)
      rescue SystemCallError, IOError => e
        raise ApiResponseError.new(
          __redact_api_key__("Could not read the upload file (#{e.class}): #{e.message}"), 0
        ), cause: nil
      end
      type = File.extname(path).casecmp('.csv').zero? ? 'text/csv' : 'application/octet-stream'
      { name: 'file', filename: File.basename(path), content: content, content_type: type }
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
        file = __file_part__(filepath)
        multipart_type, body = HttpTransport.multipart(params, file)
        response = __execute_request__(method: :post, url: url, body: body,
                                       headers: { content_type: multipart_type })

      elsif content_type == 'application/json'
        response = __execute_request__(
          method: :post,
          url: url,
          body: params.to_json,
          headers: { content_type: 'application/json', accept: 'application/json' }
        )
      elsif content_type == 'application/x-www-form-urlencoded'
        response = __execute_request__(method: :post, url: url, body: HttpTransport.encode_query(params),
                                       headers: { content_type: 'application/x-www-form-urlencoded' })
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

      options = { method: method, url: url, query: params, headers: extra }
      if form
        options[:body] = HttpTransport.encode_query(form)
        options[:headers] = extra.merge(content_type: 'application/x-www-form-urlencoded')
      elsif json
        options[:body] = json.to_json
        options[:headers] = extra.merge(content_type: 'application/json', accept: 'application/json')
      end

      __execute_request__(**options)
    end

    # A GET or form-encoded POST against an arbitrary base URL, for the list
    # evaluator, which has its own host.
    def self.root_request(method, root, path, params, form: nil)
      url = "#{__root_without_trailing_slashes__(root)}/#{path.to_s.sub(%r{\A/}, '')}"
      __parse_json_response__(__execute_with_method__(method, url, params, form: form), nil, strict: false)
    end

    # One Inbox Placement Tester call.
    def self.ipt_request(method, path, params = {}, json: nil)
      root = Zerobounce.configuration.inbox_placement_root_url
      url = "#{__root_without_trailing_slashes__(root)}/#{path.to_s.sub(%r{\A/}, '')}"
      # LIVE: the Inbox Placement Tester authenticates with a Bearer header.
      # Sent as an api_key parameter the request is rejected as unauthorized.
      response = __execute_with_method__(method, url, params, json: json, bearer: true)
      # Only a DELETE may answer with nothing (zero bytes) and succeed. On
      # every other call an empty body is an "Empty response" error, with the
      # HTTP status, from the parse below.
      return nil if method == :delete && response.body.to_s.empty?

      __parse_json_response__(response, nil, strict: false)
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

    # Whether a "success" field means failure: every value the strict boolean
    # reads as false (false, 0, "false", "False", "0", whitespace ignored).
    def self.__success_means_failure__(value)
      return true if value == false || (value.is_a?(Integer) && value.zero?)

      value.is_a?(String) && %w[false 0].include?(value.strip.downcase)
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

    # An "error" value that means failure: anything but nil or a blank String.
    def self.__error_value__(value)
      !value.nil? && !(value.is_a?(String) && value.strip.empty?)
    end

    # The keys a message-only body is made of.
    MESSAGE_KEYS = %w[error message error_message Message Error detail].freeze

    # The paths whose answer may be a bare message or an empty object: the
    # filters calls, whose documented success is {"Message": "Filter has been
    # added."}.
    RAW_JSON_PATHS = %w[filters/add filters/list filters/delete].freeze

    # A typed call never answers with an empty object or a body made only of
    # message keys (no "success"): either is how the API reports a rejected
    # request, so it is an error with the HTTP status. The exceptions are
    # validate's greylist answer {"Message": "..."} (a result), the raw-JSON
    # filters calls, and the list evaluator and Inbox Placement Tester calls
    # (which never reach this check).
    def self.__raise_if_untyped_answer__(response, parsed, path)
      return if RAW_JSON_PATHS.include?(path)

      if parsed.empty?
        raise ApiResponseError.new('ZeroBounce returned JSON of an unexpected shape: an empty object.',
                                   response.code)
      end
      return if parsed.key?('success') || !parsed.keys.all? { |key| MESSAGE_KEYS.include?(key) }
      return if path == 'validate' && ResponseError.text_of(parsed['Message'])

      text = MESSAGE_KEYS.filter_map { |key| __message_text__(parsed[key]) }.first
      if text.nil? && MESSAGE_KEYS.any? { |key| ResponseError.non_text?(parsed[key]) }
        text = ResponseError::NO_MESSAGE_TEXT
      end
      raise ApiResponseError.new(ResponseError.strip_prefix(text || 'Request failed'), response.code)
    end

    # The text of a message value: a non-blank String, or the non-blank Strings of an Array joined with "\n".
    def self.__message_text__(value)
      ResponseError.text_of(value)
    end

    # A dead or invalid key on an HTTP 200: no "success" field and a non-empty
    # "Error" (LIVE: the filters spell it so) or "error_message".
    def self.__raise_if_bare_error__(response, parsed)
      return if parsed.key?('success')

      %w[Error error_message].each do |key|
        next unless __message_text__(parsed[key])

        raise ApiResponseError.new(ResponseError.strip_prefix(parsed[key]), response.code)
      end
    end

    # The parsed JSON body. An HTML page, an empty body or one that is not
    # valid JSON raises ApiResponseError with the HTTP status.
    def self.__parse_json_body__(response)
      body = response.body.to_s
      content_type = (response.headers[:content_type] || '').to_s
      code = response.code
      if ResponseError.html?(body, content_type) || body.strip.empty?
        raise ApiResponseError.new(ResponseError.message_from_parts(code, content_type, body), code)
      end
      begin
        StrictJson.parse(body)
      rescue JSON::ParserError
        # cause: nil, or the parser's error, which quotes the body, would ride
        # along as #cause.
        raise ApiResponseError.new('ZeroBounce returned a response that is not valid JSON.', code), cause: nil
      end
    end

    # The calls whose documented answer is a JSON array: list_filters, and
    # listS3files, which may also answer {"success": true, "files": [...]}.
    # Every other call answers a JSON object.
    ARRAY_PATHS = %w[filters/list listS3files].freeze

    # E7: strict JSON of the wrong shape for the call (0, "x", null, true, an
    # array where an object is expected, an object where an array is) is an
    # API error with the HTTP status, never a result.
    def self.__require_shape__(response, parsed, path)
      return parsed if parsed.is_a?(Array) && ARRAY_PATHS.include?(path)
      # The documented field types of the answer (ResponseShape), for the calls that have a shape.
      return ResponseShape.check!(parsed, path, response.code) if parsed.is_a?(Hash) && !ARRAY_PATHS.include?(path)
      return parsed if parsed.is_a?(Hash) && path == 'listS3files' && parsed['files'].is_a?(Array)

      expected = { 'filters/list' => 'an array', 'listS3files' => 'an object with files, or an array' }
                 .fetch(path, 'an object')
      raise ApiResponseError.new("ZeroBounce returned JSON of an unexpected shape: expected #{expected}.",
                                 response.code)
    end

    # The "error" of the first entry of an "errors" array; an entry that is
    # not an object is the wrong shape (E7), not a TypeError.
    def self.__first_error__(response, errors)
      first = errors[0]
      return first['error'] if first.is_a?(Hash)

      raise ApiResponseError.new('ZeroBounce returned JSON of an unexpected shape: an errors entry is not an object.',
                                 response.code)
    end

    def self.__parse_json_response__(response, path = nil, strict: true)
      parsed = __parse_json_body__(response)
      code = response.code
      return __require_shape__(response, parsed, path) unless parsed.is_a?(Hash)

      __raise_if_success_false__(response, parsed)

      raise ApiResponseError.new(ResponseError.strip_prefix(parsed['error']), code) if __error_value__(parsed['error'])
      # The Inbox Placement Tester is a Django REST framework app and reports
      # its errors under "detail" rather than "error"/"message".
      if __error_value__(parsed['detail'])
        raise ApiResponseError.new(ResponseError.strip_prefix(parsed['detail']), code)
      end
      __raise_if_bare_error__(response, parsed)
      if parsed.key?('errors') && parsed['errors'].is_a?(Array) && !parsed['errors'].empty?
        raise ApiResponseError.new(ResponseError.strip_prefix(__first_error__(response, parsed['errors'])), code)
      end
      __raise_if_untyped_answer__(response, parsed, path) if strict
      __require_shape__(response, parsed, path)
    end

  end
end