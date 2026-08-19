# frozen_string_literal: true

require 'json'

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

    def self._get(root, path, params, content_type='application/json')

      # puts path
      # puts Zerobounce.config.apikey

      raise ("API key must be assigned") if not Zerobounce.config.apikey

      params[:api_key] = Zerobounce.config.apikey
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)

      response = RestClient::Request.execute(method: :get, url: url, timeout: 120, headers: { params: params })
      return response
    end

    def self._post(root, path, params, content_type='application/json', filepath=nil)

      raise ("API key must be assigned") if not Zerobounce.config.apikey

      params[:api_key] = Zerobounce.config.apikey
      url = "#{Zerobounce::BaseRequest.__root_without_trailing_slashes__(root)}/#{path}"
      Zerobounce::BaseRequest.__require_https__(url)
      response = nil

      if filepath or content_type == 'multipart/form-data'
        params[:file] = File.new(Zerobounce::BaseRequest.__safe_file_path__(filepath), 'rb')
        params[:multipart] = true
        response = RestClient::Request.execute(method: :post, url: url, payload: params, timeout: 120)

      elsif content_type == 'application/json'
        response = RestClient::Request.execute(
          method: :post,
          url: url,
          payload: params.to_json,
          timeout: 120,
          headers: { content_type: :json, accept: :json }
        )
      else
        # this shouldn't happen
        raise Error.new('Unknown content type specified in request.'\
          ' Must be either multipart/form-data or application/json.')
      end
      return response
    end

  end
end