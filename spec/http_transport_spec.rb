# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'socket'
require 'zlib'
require 'stringio'

# The Net::HTTP transport against a real local socket (no live API): bodies cut
# short, gzip, refused connections, multipart bytes and logging.
# rubocop:disable all
describe Zerobounce::HttpTransport do
  let(:api_key) { 'transport-key-0123456789' }

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    WebMock.disable_net_connect!(allow_localhost: true)
    example.run
  ensure
    WebMock.disable_net_connect!
    Zerobounce.configuration = saved
  end

  before { Zerobounce.configure { |c| c.apikey = api_key } }

  # Serves one raw HTTP response (a String) to the next connection and returns
  # [port, thread]; the thread's value is the raw request that arrived.
  def serve_once(raw)
    server = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      client = server.accept
      request = +''
      while (line = client.gets)
        request << line
        break if line == "\r\n"
      end
      client.write(raw)
      client.close
      server.close
      request
    end
    [server.addr[1], thread]
  end

  def run(raw, **opts)
    port, thread = serve_once(raw)
    result = begin
      described_class.execute(method: :get, url: "http://127.0.0.1:#{port}/x", **opts)
    rescue StandardError => e
      e
    end
    [result, thread.value]
  end

  it 'asks for an identity body, so Content-Length can be checked' do
    _, request = run("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}")
    expect(request.downcase).to include("accept-encoding: identity\r\n")
  end

  it 'reads a complete response' do
    response, = run("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}")
    expect([response.code, response.body, response.headers[:content_type], response.headers['Content-Type']])
      .to eq([200, '{}', 'application/json', 'application/json'])
  end

  it 'treats a gzip 200 cut short of its Content-Length as a transport failure with status 0' do
    gz = Zlib.gzip('{"credits":5,"padding":"' + ('x' * 200) + '"}')
    response, = run("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: #{gz.bytesize}\r\n\r\n".b +
                    gz.byteslice(0, gz.bytesize - 10))
    expect(response).to be_a(Zerobounce::ApiResponseError)
    expect(response.status_code).to eq(0)
    expect(response.message).to include('cut short')
  end

  it 'decodes a complete gzip body a server sends anyway' do
    gz = Zlib.gzip('{"a":1}')
    response, = run("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: #{gz.bytesize}\r\n\r\n".b + gz)
    expect(response.body).to eq('{"a":1}')
  end

  it 'treats a chunked body cut mid-stream as a transport failure with status 0' do
    response, = run("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n10\r\n{\"credits\"")
    expect(response).to be_a(Zerobounce::ApiResponseError)
    expect(response.status_code).to eq(0)
  end

  it 'wraps a refused connection in ApiResponseError, status 0, without the key' do
    Zerobounce.configuration.api_root_url = 'https://127.0.0.1:1/v2'
    Zerobounce.configuration.bulk_api_root_url = 'https://127.0.0.1:1/v2'
    [-> { Zerobounce.credits }, -> { Zerobounce.validate_file_check('f') },
     -> { Zerobounce::Warmup.new(api_key, 'https://127.0.0.1:1').seeds }].each do |call|
      expect(&call).to raise_error(Zerobounce::ApiResponseError) { |e|
        expect(e.status_code).to eq(0)
        expect(e.cause).to be_nil
        expect(e.full_message(highlight: false)).not_to include(api_key)
      }
    end
  end

  it 'sets the real client timeouts: open 30 s, read 120 s' do
    stub_request(:any, %r{\Ahttps://api\.zerobounce\.net/}).to_return(status: 200, body: '{}')
    seen = []
    allow(Net::HTTP).to receive(:start).and_wrap_original do |original, *args, **kwargs, &block|
      original.call(*args, **kwargs) do |http|
        seen << [http.open_timeout, http.read_timeout]
        block.call(http)
      end
    end
    described_class.execute(method: :get, url: 'https://api.zerobounce.net/v2/getcredits')
    expect(seen).to eq([[30, 120]])
  end

  describe 'multipart' do
    it 'builds exact bytes, with a quote as %22, CR and LF removed and UTF-8 kept raw' do
      type, body = described_class.multipart({ api_key: 'k', has_header_row: 'true' },
                                             name: 'file', filename: "a\"b\r\ncé.csv",
                                             content: "email\r\nx@y.z\n", content_type: 'text/csv')
      boundary = type[/boundary=(.+)\z/, 1]
      expect(body.encoding).to eq(Encoding::BINARY)
      expect(body).to eq(
        ("--#{boundary}\r\nContent-Disposition: form-data; name=\"api_key\"\r\n\r\nk\r\n" \
         "--#{boundary}\r\nContent-Disposition: form-data; name=\"has_header_row\"\r\n\r\ntrue\r\n" \
         "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a%22bcé.csv\"\r\n" \
         "Content-Type: text/csv\r\n\r\nemail\r\nx@y.z\n\r\n--#{boundary}--\r\n").b
      )
    end

    it 'sends the multipart header and the same bytes through the public API' do
      stub_request(:post, 'https://bulkapi.zerobounce.net/v2/sendfile').to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{"success":true,"file_id":"f1"}'
      )
      Zerobounce.validate_file_send_stream("email\na@b.c\n", "we\"ird\r\n.csv")
      expect(a_request(:post, 'https://bulkapi.zerobounce.net/v2/sendfile').with { |req|
        req.headers['Content-Type'].start_with?('multipart/form-data; boundary=') &&
          req.body.include?('filename="we%22ird.csv"') && req.body.include?("\r\n\r\nemail\na@b.c\n\r\n")
      }).to have_been_made
    end

    it 'fails with the SDK error and sends nothing when the upload stream cannot be read' do
      io = StringIO.new('x')
      allow(io).to receive(:read).and_raise(IOError, "closed, key=#{api_key}")
      expect { Zerobounce.validate_file_send_stream(io, 'a.csv') }
        .to raise_error(Zerobounce::ApiResponseError) { |e|
          expect(e.status_code).to eq(0)
          expect(e.message).not_to include(api_key)
        }
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end

  describe 'logging' do
    it 'writes nothing, whatever RESTCLIENT_LOG says, and never enables Net::HTTP debug output' do
      stub_request(:any, %r{\Ahttps://api\.zerobounce\.net/}).to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{"Credits":"1"}'
      )
      Object.const_set(:RestClient, Module.new { def self.log=(_); end }) unless defined?(RestClient)
      allow_any_instance_of(Net::HTTP).to receive(:set_debug_output).and_raise('debug output enabled')
      old = ENV.fetch('RESTCLIENT_LOG', nil)
      ENV['RESTCLIENT_LOG'] = 'stdout'
      out = StringIO.new
      $stdout = out
      $stderr = err = StringIO.new
      begin
        Zerobounce.credits
      ensure
        $stdout = STDOUT
        $stderr = STDERR
        old.nil? ? ENV.delete('RESTCLIENT_LOG') : ENV['RESTCLIENT_LOG'] = old
      end
      expect(out.string + err.string).not_to include(api_key)
      expect(out.string + err.string).to eq('')
    end
  end
end
# rubocop:enable all
