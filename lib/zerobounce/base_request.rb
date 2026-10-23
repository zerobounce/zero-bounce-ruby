# frozen_string_literal: true

require 'json'
require 'zerobounce/response_error'

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

    def self.__redact_api_key__(message)
      key = Zerobounce.config.apikey
      return message if key.nil? || key.to_s.empty?
      message.to_s.gsub(key.to_s, '***')
    end

    def self.current_api_key
      key = Thread.current[:zerobounce_api_key]
      key.nil? ? Zerobounce.config.apikey : key
    end

    def self.__execute_request__(**kwargs)
      kwargs[:max_redirects] = 0
      user_agent = Zerobounce.config.headers && Zerobounce.config.headers[:user_agent]
      kwargs[:headers] = (kwargs[:headers] || {}).merge(user_agent: user_agent) if user_agent
      RestClient::Request.execute(**kwargs)
    rescue RestClient::ExceptionWithResponse => e
      raise ResponseError.message_from(e.response)
    rescue StandardError => e
      raise e.class, __redact_api_key__(e.message)
    end

    def self._get(root, path, params, content_type='application/json')

      # puts path
      # puts Zerobounce.config.apikey

      api_key = current_api_key
      raise ('API key must be assigned') if api_key.nil? || api_key.to_s.strip.empty?

      params[:api_key] = api_key
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)

      response = __execute_request__(method: :get, url: url, timeout: 120, headers: { params: params })
      return response
    end

    def self._post(root, path, params, content_type='application/json', filepath=nil)

      api_key = current_api_key
      raise ('API key must be assigned') if api_key.nil? || api_key.to_s.strip.empty?

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
    def self.__execute_with_method__(method, url, params, form: nil, json: nil)
      raise ('API key must be assigned') if not Zerobounce.config.apikey

      params = (params || {}).merge(api_key: Zerobounce.config.apikey)
      Zerobounce::BaseRequest.__require_https__(url)

      options = { method: method, url: url, timeout: 120 }
      if form
        options[:payload] = form
        options[:headers] = { params: params, content_type: 'application/x-www-form-urlencoded' }
      elsif json
        options[:payload] = json.to_json
        options[:headers] = { params: params, content_type: :json, accept: :json }
      else
        options[:headers] = { params: params }
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
      response = __execute_with_method__(method, url, params, json: json)
      return nil if response.body.to_s.strip.empty?

      __parse_json_response__(response)
    end

    def self.bulk_api_root_without_v2
      root = Zerobounce.configuration.bulk_api_root_url.to_s.sub(%r{/v2/?$}, '')
      __root_without_trailing_slashes__(root)
    end

    def self.__parse_json_response__(response)
      body = response.body.to_s
      content_type = (response.headers[:content_type] || '').to_s
      if ResponseError.html?(body, content_type) || body.strip.empty?
        raise ResponseError.message_from_parts(response.code, content_type, body)
      end
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        raise 'ZeroBounce returned a response that is not valid JSON.'
      end
      return parsed unless parsed.is_a?(Hash)

      raise ResponseError.strip_prefix(parsed['error']) if parsed.key?('error') && !parsed['error'].nil?
      # The Inbox Placement Tester is a Django REST framework app and reports
      # its errors under "detail" rather than "error"/"message".
      raise ResponseError.strip_prefix(parsed['detail']) if parsed.key?('detail') && !parsed['detail'].nil?
      if parsed.key?('errors') && parsed['errors'].is_a?(Array) && !parsed['errors'].empty?
        raise ResponseError.strip_prefix(parsed['errors'][0]['error'])
      end
      parsed
    end

  end
end