# frozen_string_literal: true

require 'json'

module Zerobounce
  # Turns HTML pages, empty bodies, and parser dumps into a short message.
  module ResponseError
    module_function

    # A <title> sits in the head; anything past this is not one worth scanning.
    TITLE_SCAN_LIMIT = 64 * 1024

    def html?(body, content_type = '')
      sample = body.to_s[0, 2000].to_s.downcase
      content_type.to_s.downcase.include?('text/html') ||
        sample.include?('<!doctype html') ||
        sample.include?('<html') ||
        sample.include?('<head') ||
        sample.include?('<body')
    end

    def strip_prefix(message)
      text = message.to_s.strip
      loop do
        if text.start_with?('Error:')
          text = text.sub(/\AError:\s*/, '').strip
          next
        end
        if text.start_with?('[Error]:')
          text = text.sub(/\A\[Error\]:\s*/, '').strip
          next
        end
        return text
      end
    end

    # Walked with String#index instead of one <title[^>]*>(.*?)</title> match:
    # that pattern retries [^>]* from every "<title" in the body, which is
    # quadratic on a page built from repeated "<title" and was reported as a
    # polynomial ReDoS. Each step below scans forward once, and the body is
    # capped first because a title only ever lives in the head.
    def html_title(body)
      text = body.to_s[0, TITLE_SCAN_LIMIT].to_s
      open_tag = text.index(/<title[\s>]/i)
      return '' unless open_tag

      open_end = text.index('>', open_tag)
      return '' unless open_end

      close_tag = text.index(%r{</title\s*>}i, open_end + 1)
      return '' unless close_tag

      text[(open_end + 1)...close_tag].strip
    end

    def message_from_parts(status, content_type, body)
      text = body.to_s
      if html?(text, content_type)
        title = html_title(text)
        return 'ZeroBounce returned an HTML error page instead of an API response.' if title.empty?

        return "ZeroBounce returned an HTML error page (\"#{title}\") instead of an API response."
      end
      trimmed = text.strip
      return "Empty response from ZeroBounce (HTTP #{status})" if trimmed.empty?

      if trimmed.start_with?('{', '[')
        begin
          parsed = JSON.parse(trimmed)
        rescue JSON::ParserError
          return 'ZeroBounce returned a response that is not valid JSON.'
        end
        if parsed.is_a?(Hash)
          title = parsed['title'].to_s
          access = title.include?('Access denied') || title.include?('1020')
          if access && parsed['cloudflare_error'] == true
            return title
          end
          %w[error message error_message Message detail].each do |key|
            value = parsed[key]
            return strip_prefix(value) if value.is_a?(String) && !value.strip.empty?
            next unless value.is_a?(Array) && !value.empty?
            return strip_prefix(value[0]) if value[0].is_a?(String) && !value[0].strip.empty?

            # A validation error list: [{"loc" => [...], "msg" => "..."}].
            if value[0].is_a?(Hash) && value[0]['msg']
              loc = value[0]['loc']
              # loc[1..] is an endless range, which needs Ruby 2.6; the gemspec
              # supports 2.5, where it is a syntax error that stops the gem loading.
              field = loc.is_a?(Array) && loc.length > 1 ? loc[1..-1].join('.') : ''
              return field.empty? ? value[0]['msg'].to_s : "#{field}: #{value[0]['msg']}"
            end
          end
        end
        # A top-level list of strings, e.g. ["In-progress tests cannot be deleted."].
        if parsed.is_a?(Array)
          first = parsed.find { |item| item.is_a?(String) && !item.strip.empty? }
          return strip_prefix(first) if first
        end
        return 'ZeroBounce returned a response that is not valid JSON.' if trimmed.length > 1000

        return strip_prefix(trimmed)
      end
      return 'ZeroBounce returned a response that is not valid JSON.' if trimmed.length > 1000

      message = strip_prefix(trimmed)
      message.empty? ? "Empty response from ZeroBounce (HTTP #{status})" : message
    end

    def message_from(response)
      content_type = ''
      if response.respond_to?(:headers) && response.headers
        content_type = (response.headers[:content_type] || response.headers['Content-Type']).to_s
      end
      code = response.respond_to?(:code) ? response.code : 0
      message_from_parts(code, content_type, response.respond_to?(:body) ? response.body : response.to_s)
    end
  end
end
