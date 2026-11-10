# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'

RSpec.describe Zerobounce::BaseRequest do
  # Test protected helpers via send
  let(:strip_trailing_slashes) { described_class.method(:__root_without_trailing_slashes__) }
  let(:safe_file_path) { described_class.method(:__safe_file_path__) }
  let(:require_https) { described_class.method(:__require_https__) }

  describe '.__require_https__' do
    it 'allows https URLs' do
      expect { require_https.call('https://api.zerobounce.net/v2') }.not_to raise_error
    end

    it 'rejects http and other schemes' do
      expect { require_https.call('http://example.com') }.to raise_error(ArgumentError, /https:\/\//)
      expect { require_https.call('file:///etc/passwd') }.to raise_error(ArgumentError, /https:\/\//)
    end
  end

  describe '.__json_content_type__' do
    let(:json_content_type) { described_class.method(:__json_content_type__) }

    it 'matches the media type, ignoring parameters and case' do
      ['application/json',
       'application/json; charset=utf-8',
       'application/json;charset=UTF-8',
       'APPLICATION/JSON',
       '  application/json  ',
       'application/problem+json; charset=utf-8'].each do |content_type|
        expect(json_content_type.call(content_type)).to be(true), content_type
      end
    end

    it 'does not match other media types or a missing header' do
      ['text/csv', 'text/html; charset=utf-8', 'application/octet-stream',
       'application/jsonp', '', nil].each do |content_type|
        expect(json_content_type.call(content_type)).to be(false), content_type.inspect
      end
    end
  end

  describe '.__root_without_trailing_slashes__' do
    it 'returns the string unchanged when there is no trailing slash' do
      expect(strip_trailing_slashes.call('https://api.example.com')).to eq('https://api.example.com')
      expect(strip_trailing_slashes.call('')).to eq('')
    end

    it 'strips a single trailing slash' do
      expect(strip_trailing_slashes.call('https://api.example.com/')).to eq('https://api.example.com')
    end

    it 'strips multiple trailing slashes' do
      expect(strip_trailing_slashes.call('https://api.example.com///')).to eq('https://api.example.com')
      expect(strip_trailing_slashes.call('https://api.example.com//')).to eq('https://api.example.com')
    end

    it 'does not strip slashes in the middle of the URL' do
      url = 'https://api.example.com/v2/endpoint'
      expect(strip_trailing_slashes.call(url)).to eq(url)
    end

    it 'handles root URL with only slashes' do
      expect(strip_trailing_slashes.call('https://example.com///')).to eq('https://example.com')
    end

    it 'calls to_s on non-string root' do
      root = Class.new { def to_s; 'https://api.example.com/'; end }.new
      expect(strip_trailing_slashes.call(root)).to eq('https://api.example.com')
    end
  end

  describe '.__safe_file_path__' do
    it 'raises ArgumentError when filepath is nil' do
      expect { safe_file_path.call(nil) }.to raise_error(ArgumentError, 'File path is required')
    end

    it 'raises ArgumentError when filepath is empty string' do
      expect { safe_file_path.call('') }.to raise_error(ArgumentError, 'File path is required')
    end

    it 'raises when filepath is only whitespace' do
      # Implementation does not strip; expand_path produces path that does not exist
      expect { safe_file_path.call("   \t ") }.to raise_error(Errno::ENOENT)
    end

    it 'raises ArgumentError for path traversal outside current directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect { safe_file_path.call('../../etc/passwd') }.to raise_error(ArgumentError, 'File path must be under the current directory')
          expect { safe_file_path.call('../other/file.csv') }.to raise_error(ArgumentError, 'File path must be under the current directory')
        end
      end
    end

    it 'raises ArgumentError when path resolves to a directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('subdir')
          expect { safe_file_path.call('subdir') }.to raise_error(ArgumentError, 'File path must point to a regular file')
        end
      end
    end

    it 'raises Errno::ENOENT when file does not exist' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect { safe_file_path.call('nonexistent.csv') }.to raise_error(Errno::ENOENT)
        end
      end
    end

    it 'returns canonical path for a valid relative file under cwd' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('upload.csv', 'a,b')
          result = safe_file_path.call('upload.csv')
          expect(result).to eq(File.realpath('upload.csv'))
          expect(File.exist?(result)).to be true
          expect(File.file?(result)).to be true
        end
      end
    end

    it 'returns canonical path for a valid file in a subdirectory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('data')
          File.write('data/file.csv', 'x')
          result = safe_file_path.call('data/file.csv')
          expect(result).to eq(File.realpath('data/file.csv'))
          expect(File.file?(result)).to be true
        end
      end
    end

    it 'rejects path that expands outside cwd even if file does not exist' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          # Expanded path is outside dir; realpath would raise ENOENT, but we check expanded first
          outside = File.join(dir, '..', 'outside.csv')
          expect { safe_file_path.call(outside) }.to raise_error(ArgumentError, 'File path must be under the current directory')
        end
      end
    end

    it 'accepts path with . and returns canonical path' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('f.csv', 'x')
          result = safe_file_path.call('./f.csv')
          expect(result).to eq(File.realpath('f.csv'))
        end
      end
    end

    it 'calls to_s on non-string filepath' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('f.csv', 'x')
          pathlike = Class.new { def to_s; 'f.csv'; end }.new
          result = safe_file_path.call(pathlike)
          expect(result).to eq(File.realpath('f.csv'))
        end
      end
    end
  end
end

# Error behaviour of the validation client's request layer: which class is
# raised, what its message says, and that the API key never reaches it.
RSpec.describe 'request errors' do
  json = { 'Content-Type' => 'application/json' }

  around do |example|
    original = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    Zerobounce.configure { |config| config.apikey = 'GLOBALKEY777' }
    example.run
  ensure
    Zerobounce.configuration = original
    Thread.current[:zerobounce_api_key] = nil
  end

  # Everything a caller (or an uncaught-exception printer) can read off the
  # error without digging into the HTTP response object.
  def visible_text(error)
    [error.message, error.inspect, error.full_message(highlight: false), error.cause&.message].join("\n")
  end

  describe 'API key redaction' do
    before do
      # A space makes the URL unparseable, so the HTTP library raises before
      # sending and quotes the whole URL - query string and key included.
      Zerobounce.configure { |config| config.api_root_url = 'https://bad host.example/v2/' }
    end

    it 'redacts the key of a Zerobounce::Client' do
      expect { Zerobounce::Client.new('CLIENTKEY999').validate('person@example.com') }
        .to raise_error(StandardError) { |error|
          expect(error.message).to include('***')
          expect(visible_text(error)).not_to include('CLIENTKEY999')
        }
    end

    it 'redacts the URL-encoded form of a key' do
      expect { Zerobounce::Client.new('client+key/999').credits }
        .to raise_error(StandardError) { |error|
          expect(visible_text(error)).not_to include('client%2Bkey%2F999')
          expect(visible_text(error)).not_to include('client+key/999')
        }
    end

    it 'redacts a key set with with_api_key' do
      expect { Zerobounce.with_api_key('SCOPEDKEY555') { Zerobounce.activity('person@example.com') } }
        .to raise_error(StandardError) { |error| expect(visible_text(error)).not_to include('SCOPEDKEY555') }
    end

    it 'still redacts the global key' do
      expect { Zerobounce.validate('person@example.com') }
        .to raise_error(StandardError) { |error|
          expect(error.message).to include('***')
          expect(visible_text(error)).not_to include('GLOBALKEY777')
        }
    end

    it 'redacts a key echoed back in an HTTP error body' do
      Zerobounce.configure { |config| config.api_root_url = 'https://api.zerobounce.net/v2/' }
      stub_request(:get, %r{api\.zerobounce\.net/v2/validate})
        .to_return(status: 400, headers: json, body: '{"error":"Unknown api_key CLIENTKEY999"}')
      expect { Zerobounce::Client.new('CLIENTKEY999').validate('person@example.com') }
        .to raise_error(RuntimeError, 'Unknown api_key ***')
    end
  end

  describe 'HTTP error statuses' do
    it 'raises the RestClient class for the status, as 2.1.8 did, with the short API message' do
      stub_request(:get, %r{bulkapi\.zerobounce\.net/v2/filestatus})
        .to_return(status: 404, headers: json, body: '{"error":"Error: File not found"}')
      expect { Zerobounce.validate_file_check('missing') }
        .to raise_error(RestClient::NotFound, 'File not found') { |error|
          expect(error.http_code).to eq(404)
          expect(error).to be_a(RuntimeError)
        }
    end

    it 'keeps an HTML error page out of the message but on the RestClient error' do
      page = '<!DOCTYPE html><html><head><title>Access denied | zerobounce.net</title></head>' \
             '<body>blocked</body></html>'
      stub_request(:get, %r{api\.zerobounce\.net/v2/getcredits})
        .to_return(status: 403, headers: { 'Content-Type' => 'text/html' }, body: page)
      expect { Zerobounce.credits }
        .to raise_error(RestClient::Forbidden) { |error|
          expect(error.http_code).to eq(403)
          expect(error.message).to include('Access denied')
          expect(error.message).not_to include('<body>')
        }
    end

    it 'reports a redirect as a redirect and does not follow it' do
      stub_request(:get, %r{api\.zerobounce\.net/v2/validate})
        .to_return(status: 302, headers: { 'Location' => 'https://elsewhere.example/collect' }, body: '')
      stub_request(:any, /elsewhere\.example/)
      expect { Zerobounce.validate('person@example.com') }
        .to raise_error(RestClient::Found, 'ZeroBounce answered with a redirect (HTTP 302), which is not followed')
      expect(a_request(:any, /elsewhere\.example/)).not_to have_been_made
    end
  end

  describe '{"success": false} on an HTTP 200' do
    it 'raises on the main API, as it does on the bulk API' do
      body = '{"success":false,"message":"The request could not be processed."}'
      stub_request(:get, %r{api\.zerobounce\.net/v2/(validate|activity|guessformat)})
        .to_return(status: 200, headers: json, body: body)
      stub_request(:post, %r{api\.zerobounce\.net/v2/scoring})
        .to_return(status: 200, headers: json, body: body)
      calls = {
        'validate' => -> { Zerobounce.validate('person@example.com') },
        'activity' => -> { Zerobounce.activity('person@example.com') },
        'find_domain' => -> { Zerobounce.find_domain(domain: 'example.com') },
        'score_email POST' => -> { Zerobounce.score_email('person@example.com', use_post: true) }
      }
      calls.each do |name, call|
        expect { call.call }.to raise_error(RuntimeError, 'The request could not be processed.'), name
      end
    end

    it 'still returns a result whose success is true' do
      stub_request(:get, %r{api\.zerobounce\.net/v2/activity})
        .to_return(status: 200, headers: json, body: '{"success":true,"found":true}')
      expect(Zerobounce.activity('person@example.com')).to eq('success' => true, 'found' => true)
    end
  end
end
