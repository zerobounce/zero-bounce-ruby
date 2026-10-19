# frozen_string_literal: true

require 'webmock/rspec'
require 'zerobounce'

RSpec.describe 'offline API' do
  def html_page
    "<!DOCTYPE html><html><head><title>Access denied | zerobounce.net | Zero Bounce</title></head><body>#{'<p>blocked</p>' * 20_000}</body></html>"
  end

  def answer(request)
    uri = request.uri
    key = uri.query_values.to_h['api_key'].to_s
    body = request.body.to_s
    if body.include?('api_key=')
      key = URI.decode_www_form(body).to_h['api_key'].to_s if key.empty?
    end
    if key.empty? && body.start_with?('{')
      begin
        parsed = JSON.parse(body)
        key = parsed['api_key'].to_s
      rescue JSON::ParserError
        key = ''
      end
    end
    path = uri.path
    status = 200
    content_type = 'application/json'
    payload = '{"Credits":"7","address":"' + key + '","status":"valid","email":"' + key + '","domain":"' + key + '","success":true,"message":"ok","file_id":"' + key + '","file_name":"f.csv","email_batch":[{"address":"' + key + '","status":"valid"}],"errors":[]}'
    if key.start_with?('html-403-')
      status = 403
      content_type = 'text/html'
      payload = html_page
    elsif key.start_with?('html-200-')
      content_type = 'text/html'
      payload = html_page
    elsif key.start_with?('empty-')
      payload = ''
    elsif key.start_with?('malformed-')
      payload = "<<<not-json>>>#{'x' * 5000}"
    elsif key.start_with?('cf-json-')
      status = 403
      payload = '{"title":"Error 1020: Access denied","status":403,"detail":"The request was blocked by a Cloudflare firewall rule configured by the site owner.","error_code":1020,"cloudflare_error":true,"type":"https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1020/"}'
    elsif key.start_with?('double-error-')
      status = 400
      content_type = 'text/plain'
      payload = 'Error: Error: api_key is invalid'
    elsif path.include?('validatebatch') && key.start_with?('batch-account-')
      payload = '{"email_batch":[],"errors":[{"email_address":"all","error":"Invalid API Key or your account ran out of credits"}]}'
    elsif path.include?('validatebatch') && key.start_with?('batch-partial-')
      payload = '{"email_batch":[{"address":"good@example.com","status":"valid"}],"errors":[{"email_address":"bad@","error":"Invalid email address"}]}'
    elsif path.include?('getfile')
      content_type = 'application/octet-stream'
      payload = "email\n#{key}@example.com\n"
    end
    sleep(rand * 0.01)
    { status: status, headers: { 'Content-Type' => content_type }, body: payload }
  end

  before do
    @requests = []
    stub_request(:any, /zerobounce\.net/).to_return do |request|
      @requests << request
      answer(request)
    end
    Zerobounce.configure { |config| config.apikey = 'offline-key' }
  end

  after do
    Thread.current[:zerobounce_api_key] = nil
  end

  it 'matches the gem version in the user agent' do
    expect(Zerobounce::VERSION).to eq('2.1.8')
    expect(Zerobounce::Configuration.new.headers[:user_agent]).to include(Zerobounce::VERSION)
  end

  it 'calls credits and validate with the right parameters' do
    expect(Zerobounce.credits).to eq(7)
    request = @requests.pop
    expect(request.method).to eq(:get)
    expect(request.uri.host).to eq('api.zerobounce.net')
    expect(request.uri.path).to eq('/v2/getcredits')
    expect(request.uri.query_values['api_key']).to eq('offline-key')

    result = Zerobounce.validate('person@example.com', nil, activity_data: false, verify_plus: true)
    request = @requests.pop
    expect(request.uri.path).to eq('/v2/validate')
    expect(request.uri.query_values['activity_data']).to eq('false')
    expect(request.uri.query_values['verify_plus']).to eq('true')
    expect(request.uri.query_values).not_to have_key('timeout')
    expect(result['address']).to eq('offline-key')
  end

  it 'keeps a partial batch success and fails an account-level batch error' do
    Zerobounce.configure { |config| config.apikey = 'batch-partial-user' }
    result = Zerobounce.validate_batch(['good@example.com', 'bad@'])
    expect(result['email_batch'].first['address']).to eq('good@example.com')
    expect(result['errors'].first['email_address']).to eq('bad@')

    Zerobounce.configure { |config| config.apikey = 'batch-account-user' }
    expect { Zerobounce.validate_batch(['a@example.com']) }.to raise_error(RuntimeError, /Invalid API Key/)
  end

  it 'returns short errors for html, empty, malformed, cloudflare, and doubled prefixes' do
    Zerobounce.configure { |config| config.apikey = 'html-403-user' }
    expect { Zerobounce.credits }.to raise_error(RuntimeError) { |error|
      expect(error.message.length).to be < 500
      expect(error.message).to include('Access denied')
      expect(error.message).not_to include('<p>blocked</p>')
    }
    expect(html_page.length).to be > 100_000

    Zerobounce.configure { |config| config.apikey = 'html-200-user' }
    expect { Zerobounce.validate('a@example.com') }.to raise_error(RuntimeError, /Access denied/)

    Zerobounce.configure { |config| config.apikey = 'empty-user' }
    expect { Zerobounce.validate('a@example.com') }.to raise_error(RuntimeError, /Empty response/)

    Zerobounce.configure { |config| config.apikey = 'malformed-user' }
    expect { Zerobounce.validate('a@example.com') }.to raise_error(RuntimeError, /not valid JSON/) { |error|
      expect(error.message).not_to include('<<<not-json>>>')
    }

    Zerobounce.configure { |config| config.apikey = 'cf-json-user' }
    expect { Zerobounce.credits }.to raise_error(RuntimeError, /Access denied/) { |error|
      expect(error.message).not_to include('developers.cloudflare.com')
    }

    Zerobounce.configure { |config| config.apikey = 'double-error-user' }
    expect { Zerobounce.activity('a@example.com') }.to raise_error(RuntimeError, 'api_key is invalid')
  end

  it 'rejects an empty key and a bad timeout before a request' do
    Zerobounce.configure { |config| config.apikey = '' }
    expect { Zerobounce.credits }.to raise_error(RuntimeError, /API key must be assigned/)
    expect(@requests).to be_empty

    Zerobounce.configure { |config| config.apikey = 'keyed' }
    expect { Zerobounce.validate('a@example.com', nil, timeout: 2) }.to raise_error(ArgumentError, /timeout/)
    expect { Zerobounce.validate_batch(['a@example.com'], timeout: 9) }.to raise_error(ArgumentError, /timeout/)
    expect(@requests).to be_empty
  end

  it 'does not mix keys across client threads' do
    echoes = Array.new(8)
    threads = 8.times.map do |index|
      Thread.new do
        key = "conc-#{index}"
        echoes[index] = Zerobounce::Client.new(key).validate('person@example.com')['address']
      end
    end
    threads.each(&:join)
    keys = @requests.map { |request| request.uri.query_values['api_key'] }
    expect(keys.sort).to eq(8.times.map { |index| "conc-#{index}" }.sort)
    expect(echoes).to eq(8.times.map { |index| "conc-#{index}" })
  end
end
