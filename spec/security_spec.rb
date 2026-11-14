# frozen_string_literal: true

# rubocop:disable all

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'API key and URL hygiene' do
  let(:key) { 'dummy-offline-key-123' }

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    Zerobounce.configuration.apikey = key
    example.run
  ensure
    Zerobounce.configuration = saved
    Thread.current[:zerobounce_api_key] = nil
  end

  before { allow(Zerobounce).to receive(:warn) }

  BAD_URLS = [
    'https://api.zerobounce.net@evil.example/v2',
    'https://u:p@evil.example/',
    'https://api.zerobounce.net:pw@evil.example',
    'https://exa mple.com',
    "https://example.com\n/v2",
    "https://example.com\t",
    "https://example.com\u200b/v2",
    "https://example.com\u00a0",
    'https://example.com\\@evil.example',
    'https://',
    'https:///v2',
    'https://:443/v2',
    'https://example.com:/v2',
    'https://example.com:0/v2',
    'https://example.com:99999/v2',
    'https://example.com:abc/v2',
    'https://-bad-.example/v2',
    'https://exa_mple.com/v2',
    'https://[::1/v2',
    'https://[zz::1]/v2',
    "https://b\u00fccher.example/v2",
    'http://example.com/v2',
    ''
  ].freeze

  GOOD_URLS = ['https://api.zerobounce.net/v2/', 'https://example.com:8443/v2', 'https://[::1]:8443/x',
               'HTTPS://Example.COM/v2'].freeze

  describe 'base URLs' do
    %i[api_root_url bulk_api_root_url list_evaluator_root_url inbox_placement_root_url bulk_root_url].each do |setter|
      BAD_URLS.each do |url|
        next if setter == :bulk_root_url && url.strip.empty?

        it "refuses #{url.inspect} for #{setter} at configuration" do
          expect { Zerobounce.configuration.public_send(:"#{setter}=", url) }.to raise_error(ArgumentError, %r{https://})
        end
      end

      it "accepts valid https URLs for #{setter}" do
        GOOD_URLS.each { |url| expect { Zerobounce.configuration.public_send(:"#{setter}=", url) }.not_to raise_error }
      end
    end

    it 'lets bulk_root_url be unset, to derive it' do
      expect { Zerobounce.configuration.bulk_root_url = nil }.not_to raise_error
      expect { Zerobounce.configuration.bulk_root_url = '' }.not_to raise_error
    end

    it 'refuses a bad URL from the environment' do
      stub_const('ENV', ENV.to_h.merge('ZEROBOUNCE_API_URL' => 'https://api.zerobounce.net@evil.example/v2'))
      expect { Zerobounce::Configuration.new }.to raise_error(ArgumentError)
    end

    # A URL set behind the setters (instance_variable_set) is still refused on the send.
    {
      main: [:@api_root_url, -> { Zerobounce.credits }],
      bulk: [:@bulk_api_root_url, -> { Zerobounce.validate_file_check('f1') }],
      s3: [:@bulk_root_url, -> { Zerobounce.s3_bulk_status('f1') rescue Zerobounce.bulk_root_probe }],
      evaluator: [:@list_evaluator_root_url, -> { Zerobounce.get_list_evaluator_result('f1') }],
      ipt: [:@inbox_placement_root_url, -> { Zerobounce.inbox_placement_providers }]
    }.each do |name, (ivar, call)|
      next if name == :s3

      it "re-checks the #{name} root on every send" do
        Zerobounce.configuration.instance_variable_set(ivar, 'https://api.zerobounce.net@evil.example/v2')
        expect { call.call }.to raise_error(ArgumentError, %r{https://})
        expect(WebMock).not_to have_requested(:any, /.*/)
      end
    end

    it 're-checks the S3/SFTP bulk root on every send' do
      Zerobounce.configuration.instance_variable_set(:@bulk_root_url, 'https://bulkapi.zerobounce.net@evil.example')
      expect { Zerobounce::BaseRequest.root_request(:get, Zerobounce::BaseRequest.bulk_api_root_without_v2, 's3/x', {}) }
        .to raise_error(ArgumentError, %r{https://})
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it 'checks the URL inside the single send path, whoever built it' do
      expect do
        Zerobounce::BaseRequest.__execute_request__(method: :get, url: 'https://u:p@evil.example/x')
      end.to raise_error(ArgumentError)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end

  describe 'Warmup base_url' do
    BAD_URLS.each do |url|
      it "refuses #{url.inspect} at construction" do
        expect { Zerobounce::Warmup.new(key, url) }.to raise_error(ArgumentError, %r{https://})
      end
    end

    it 're-checks the root on every send' do
      warmup = Zerobounce::Warmup.new(key)
      warmup.instance_variable_set(:@root, 'https://warmup-api.zerobounce.net@evil.example/api/v1/warmup')
      expect { warmup.list_sending_accounts }.to raise_error(ArgumentError, %r{https://})
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end

  describe 'request logging' do
    it 'writes no request line, URL or header from lib' do
      lib = File.expand_path('../lib', __dir__)
      text = Dir[File.join(lib, '**/*.rb')].map { |file| File.read(file).gsub(/^\s*#.*$/, '') }.join("\n")
      expect(text).not_to match(/set_debug_output|RestClient|Logger\.new|\$stderr\.puts|\$stdout\.puts|^\s*puts\b/)
    end

    it 'carries no response body or response object on the error' do
      stub_request(:get, %r{api\.zerobounce\.net/v2/getcredits})
        .to_return(status: 400, headers: { 'Content-Type' => 'application/json' }, body: %({"error":"bad #{key}"}))
      expect { Zerobounce.credits }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.instance_variables).to contain_exactly(:@status_code)
        expect(error).not_to respond_to(:response)
        expect(error).not_to respond_to(:http_body)
        expect(error.message).to eq('bad ***')
      }
    end
  end

  describe 'API key characters' do
    [
      "key\u00a0", "ke\u2003y", "ke\u2028y", "\u3000key", "ke\u200by", "\ufeffkey", "ke\u180ey", "key\n", ' key', "ke\u0085y"
    ].each do |bad|
      it "refuses #{bad.inspect} anywhere: global, Client, Warmup, with_api_key" do
        Zerobounce.configuration.apikey = bad
        expect { Zerobounce.credits }.to raise_error(ArgumentError, /whitespace, control or invisible/)
        expect { Zerobounce::Client.new(bad) }.to raise_error(ArgumentError, /whitespace, control or invisible/)
        expect { Zerobounce::Warmup.new(bad) }.to raise_error(ArgumentError, /whitespace, control or invisible/)
        expect { Zerobounce.with_api_key(bad) { Zerobounce.credits } }.to raise_error(ArgumentError)
        expect(WebMock).not_to have_requested(:any, /.*/)
      end
    end

    ["k\u00e9y", "key\u00fc", "\u65e5\u672c"].each do |bad|
      it "refuses the non-ASCII key #{bad.inspect}" do
        expect { Zerobounce::Client.new(bad) }.to raise_error(ArgumentError, /cannot be sent in an HTTP header/)
        expect { Zerobounce::Warmup.new(bad) }.to raise_error(ArgumentError, /cannot be sent in an HTTP header/)
      end
    end

    it 'accepts printable ASCII, including + / % and quotes' do
      expect { Zerobounce::Client.new(%(a+b/c%d"e'f)) }.not_to raise_error
    end
  end

  describe 'redaction' do
    let(:redact) { Zerobounce::ApiKey.method(:redact) }

    it 'masks the key whatever the letter case, raw and encoded' do
      secret = 'AbCd1234EfGh5678'
      [secret.upcase, secret.downcase, secret, ERB::Util.url_encode(secret).upcase].each do |echo|
        expect(redact.call("bad key #{echo}.", [secret])).to eq('bad key ***.')
      end
      expect(redact.call(%({"error":"#{secret.downcase}"}), [secret])).to eq('{"error":"***"}')
    end

    it 'masks a mixed-case echo of a URL-encoded key' do
      secret = 'a+b/c=d&e-key-9'
      echo = ERB::Util.url_encode(secret).downcase
      expect(redact.call("see #{echo}", [secret])).to eq('see ***')
    end

    it 'omits a text whose decoded view, in another case, still holds the key' do
      secret = 'ZqKey-Secret-77'
      echo = secret.downcase.each_char.map { |c| format('%%%02X', c.ord) }.join
      expect(redact.call("x #{echo}", [secret])).to eq(Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE)
    end

    it 'redacts HTML-entity echoes' do
      secret = "dummy-key-it's-9"
      ["dummy-key-it&#39;s-9", 'dummy-key-it&#x27;s-9', 'dummy-key-it&apos;s-9', '&#100;ummy-key-it&#39;s-9',
       '&#x64;ummy-key-it&#x27;s-9'].each do |echo|
        expect(redact.call("bad #{echo}", [secret])).to eq(Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE), echo
      end
      expect(redact.call('bad &#100;ummy-offline', ['dummy-offline'])).to eq(Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE)
    end

    it 'redacts a backslash-escaped quote echo' do
      secret = "dummy-it's-key-9"
      expect(redact.call("bad dummy-it\\'s-key-9", [secret])).to eq(Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE)
    end

    it 'redacts the key in an upper-case 400 text and a 200 {"error":...} body through the client' do
      stub_request(:get, %r{api\.zerobounce\.net/v2/getcredits})
        .to_return(status: 400, headers: { 'Content-Type' => 'application/json' },
                   body: %({"error":"Invalid #{key.upcase}"}))
      expect { Zerobounce.credits }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect([error.message, error.inspect, error.full_message(highlight: false)].join).not_to match(/#{key}/i)
      }
      stub_request(:get, %r{api\.zerobounce\.net/v2/getcredits})
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: %({"error":"Invalid #{key.upcase}"}))
      expect { Zerobounce.credits }.to raise_error(RuntimeError) { |error|
        expect([error.message, error.inspect, error.full_message(highlight: false)].join).not_to match(/#{key}/i)
      }
    end

    it 'redacts the Warmup key and the SMTP password in a 500 body, in any case' do
      warmup = Zerobounce::Warmup.new('warmup-dummy-key-1')
      stub_request(:any, /warmup-api/).to_return(
        status: 500, headers: { 'Content-Type' => 'text/plain' },
        body: 'failed WARMUP-DUMMY-KEY-1 and Smtp-Password-9'
      )
      expect { warmup.test_smtp_configuration('a@b.com', 'user', 'smtp-password-9', 'smtp.example.com', 587) }
        .to raise_error(Zerobounce::ApiResponseError) { |error|
          expect(error.message).to eq('failed *** and ***')
        }
    end

    describe 'short secrets' do
      it 'does not mangle ordinary words for a one-character password' do
        expect(redact.call('Failed to open the file', ['p'])).to eq('Failed to open the file')
        expect(redact.call('Failed to open the file', ['o'])).to eq('Failed to open the file')
        expect(redact.call('password is p.', ['p'])).to eq('password is ***.')
      end

      it 'masks a short secret that stands as a whole token, in any case' do
        expect(redact.call('user=ab12 pass=AB12;', ['ab12'])).to eq('user=*** pass=***;')
        expect(redact.call('connect failed: p', ['p'])).to eq('connect failed: ***')
      end

      it 'masks a password of 8 characters or more wherever it occurs' do
        expect(redact.call('xxpassw0rdxx', ['passw0rd'])).to eq('xx***xx')
      end

      it 'omits a text whose decoded view holds a short secret as a whole token' do
        expect(redact.call('x %70', ['p'])).to eq(Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE)
      end

      it 'keeps an SMTP failure readable with a one-character password' do
        warmup = Zerobounce::Warmup.new('warmup-dummy-key-1')
        stub_request(:any, /warmup-api/).to_return(
          status: 500, headers: { 'Content-Type' => 'text/plain' }, body: 'Failed to open the connection'
        )
        expect { warmup.test_smtp_configuration('a@b.com', 'u', 'p', 'smtp.example.com', 587) }
          .to raise_error(Zerobounce::ApiResponseError, 'Failed to open the connection')
      end
    end
  end
end
# rubocop:enable all
