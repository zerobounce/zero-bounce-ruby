# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength

# What goes on the wire for configured base URLs and optional parameters, and
# what an error carries along with it. Every request is stubbed with WebMock;
# nothing here reaches the live API.
describe 'Request URLs, optional parameters and wrapped errors' do
  let(:api_key) { 'hygiene-key-0123456789' }

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  def last_request
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
  end

  def json_reply(body = '{}')
    { status: 200, body: body, headers: { 'Content-Type' => 'application/json' } }
  end

  describe 'validate without an IP address' do
    before do
      stub_request(:any, %r{\Ahttps://api\.zerobounce\.net/v2/validate})
        .to_return(json_reply('{"address":"a@example.com","status":"valid"}'))
    end

    it 'leaves ip_address out, as the other SDKs do' do
      [nil, ''].each do |ip|
        Zerobounce.validate('a@example.com', ip)
        expect(last_request.uri.query.to_s).not_to include('ip_address'), "GET with #{ip.inspect}"
        Zerobounce.validate('a@example.com', ip, use_post: true)
        expect(last_request.body.to_s).not_to include('ip_address'), "POST with #{ip.inspect}"
      end
    end

    it 'still sends an IP address that is given' do
      Zerobounce.validate('a@example.com', '0')
      expect(URI.decode_www_form(last_request.uri.query.to_s).to_h).to include('ip_address' => '0')
    end
  end

  describe 'list evaluator base URL' do
    let(:file) { File.join('spec', 'fixtures', 'priority3_finder.csv') }

    it 'sends the upload and the result fetch to list_evaluator_root_url' do
      Zerobounce.configuration.list_evaluator_root_url = 'https://evaluator.example.test/le/'
      stub_request(:any, %r{\Ahttps://evaluator\.example\.test/le/})
        .to_return(json_reply('{"success":true,"file_id":"f1"}'))

      Zerobounce.send_list_evaluator_file(file, email_address_column: 1)
      expect(last_request.method).to eq(:post)
      expect([last_request.uri.host, last_request.uri.path]).to eq(['evaluator.example.test', '/le/'])
      Zerobounce.get_list_evaluator_result('f1')
      expect([last_request.uri.host, last_request.uri.path]).to eq(['evaluator.example.test', '/le/f1/'])
    end

    it 'keeps the default upload URL' do
      stub_request(:post, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/listevaluator/})
        .to_return(json_reply('{"success":true,"file_id":"f1"}'))
      Zerobounce.send_list_evaluator_file(file, email_address_column: 1)
      expect(last_request.uri.path).to eq('/v2/listevaluator/')
    end
  end

  describe 'S3 and SFTP root derived from bulk_api_root_url' do
    it 'strips /v2 even when the configured URL ends in several slashes' do
      ['https://bulk.example.test/v2//', 'https://bulk.example.test/v2/', 'https://bulk.example.test/v2'].each do |url|
        Zerobounce.configuration.bulk_api_root_url = url
        stub_request(:get, %r{\Ahttps://bulk\.example\.test/listS3files}).to_return(json_reply('[]'))
        Zerobounce.list_s3_files
        expect(last_request.uri.path).to eq('/listS3files'), url
      end
    end
  end

  describe 'Warmup transport errors' do
    it 'does not keep the unredacted original as #cause' do
      warmup = Zerobounce::Warmup.new(api_key)
      allow(RestClient::Request).to receive(:execute)
        .and_raise(SocketError, "getaddrinfo failed, key=#{api_key}")

      expect { warmup.seeds }.to raise_error(SocketError) { |error|
        expect(error.message).not_to include(api_key)
        expect(error.cause).to be_nil
        expect(error.full_message(highlight: false)).not_to include(api_key)
      }
    end
  end
end
# rubocop:enable Metrics/BlockLength
