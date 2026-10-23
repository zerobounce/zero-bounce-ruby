# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# Offline specs for the endpoints ported from the Python SDK that were not
# already on develop: the WHOIS and greylist validate options, the S3 email
# finder / domain search, the SFTP/FTP bulk jobs, and the Inbox Placement
# Tester.
#
# Every request is stubbed with WebMock; nothing here reaches the live API.
describe 'Validate WHOIS and greylist options, SFTP bulk and the Inbox Placement Tester' do
  let(:api_key) { 'offline-key' }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  def last_request
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
  end

  def last_form
    URI.decode_www_form(last_request.body.to_s).to_h
  end

  def last_query
    URI.decode_www_form(last_request.uri.query.to_s).to_h
  end

  describe 'validate options' do
    before do
      stub_request(:any, %r{\Ahttps://api\.zerobounce\.net/v2/validate})
        .to_return(
          status: 200,
          body: '{"address":"a@example.com","status":"valid"}',
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends domain_info, greylist_processing and callback_url only when given' do
      Zerobounce.validate('a@example.com')
      %w[domain_info greylist_processing callback_url].each do |absent|
        expect(last_query).not_to have_key(absent)
      end

      Zerobounce.validate(
        'a@example.com', nil,
        domain_info: true,
        greylist_processing: true,
        callback_url: 'https://example.com/greylist'
      )
      # Booleans go on the wire as the strings "true"/"false".
      expect(last_query).to include(
        'domain_info' => 'true',
        'greylist_processing' => 'true',
        'callback_url' => 'https://example.com/greylist'
      )
    end

    it 'sends the same fields as a form body with use_post' do
      Zerobounce.validate('a@example.com', nil, domain_info: false,
                                                greylist_processing: true,
                                                callback_url: 'https://example.com/greylist',
                                                use_post: true)
      expect(last_request.method).to eq(:post)
      expect(last_form).to include('domain_info' => 'false',
                                   'callback_url' => 'https://example.com/greylist')
    end

    it 'rejects a callback_url without greylist_processing before any request' do
      expect { Zerobounce.validate('a@example.com', nil, callback_url: 'https://example.com/cb') }
        .to raise_error(ArgumentError, /greylist_processing/)
      expect do
        Zerobounce.validate('a@example.com', nil, greylist_processing: false,
                                                  callback_url: 'https://example.com/cb')
      end.to raise_error(ArgumentError, /greylist_processing/)
      expect do
        Zerobounce.validate('a@example.com', nil, greylist_processing: true, callback_url: '   ')
      end.to raise_error(ArgumentError, /callback_url/)

      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})
    end
  end

  describe 'S3 and SFTP/FTP bulk jobs' do
    before do
      stub_request(:any, %r{\Ahttps://bulkapi\.zerobounce\.net/\w+})
        .to_return(status: 200, body: '{"success":true,"file_id":"fid"}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'posts to the bulkapi root, without /v2' do
      Zerobounce.email_finder_s3_file('lists/leads.csv', true)
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.path).to eq('/emailFinderS3file')
      expect(last_form).to include('file_name' => 'lists/leads.csv', 'has_header_row' => 'true')
      # Unset options stay off the request entirely.
      expect(last_form).not_to have_key('remove_duplicates')
      expect(last_form).not_to have_key('return_url')
    end

    it 'sends remove_duplicates and return_url only when given' do
      Zerobounce.domain_search_s3_file('lists/leads.csv', false,
                                       remove_duplicates: true,
                                       return_url: 'https://example.com/done')
      expect(last_request.uri.path).to eq('/domainSearchS3file')
      expect(last_form).to include(
        'has_header_row' => 'false',
        'remove_duplicates' => 'true',
        'return_url' => 'https://example.com/done'
      )
    end

    it 'treats file_name as optional for validateSFTPfile alone' do
      # Without it the input bucket from the account's settings is used.
      Zerobounce.validate_sftp_file(nil, true)
      expect(last_request.uri.path).to eq('/validateSFTPfile')
      expect(last_form).not_to have_key('file_name')
      expect(last_form['has_header_row']).to eq('true')

      Zerobounce.validate_sftp_file('my_file.txt', true)
      expect(last_form['file_name']).to eq('my_file.txt')
    end

    it 'posts each remaining job to its documented path' do
      {
        'scoreSFTPfile' => :score_sftp_file,
        'emailFinderSFTPfile' => :email_finder_sftp_file,
        'domainSearchSFTPfile' => :domain_search_sftp_file
      }.each do |path, method|
        Zerobounce.public_send(method, 'my_file.txt', true)
        expect(last_request.uri.path).to eq("/#{path}")
      end
    end

    it 'exports with export_path, not export_bucket' do
      Zerobounce.export_sftp_file(file_id: 'fid', export_path: '/exports')
      expect(last_request.uri.path).to eq('/exportSFTPfile')
      expect(last_form).to include('file_id' => 'fid', 'export_path' => '/exports')
      expect(last_form).not_to have_key('export_bucket')

      Zerobounce.export_sftp_file(file_id: 'fid')
      expect(last_form).not_to have_key('export_path')
    end

    it 'rejects a missing or blank file name before any request' do
      %i[email_finder_s3_file domain_search_s3_file score_sftp_file
         email_finder_sftp_file domain_search_sftp_file].each do |method|
        expect { Zerobounce.public_send(method, nil, true) }
          .to raise_error(ArgumentError, /file_name/)
        expect { Zerobounce.public_send(method, '   ', true) }
          .to raise_error(ArgumentError, /file_name/)
      end
      # An unset name is allowed here, but a blank one is not.
      expect { Zerobounce.validate_sftp_file('  ', true) }
        .to raise_error(ArgumentError, /file_name/)

      expect { Zerobounce.export_sftp_file(file_id: '  ') }.to raise_error(ArgumentError, /file_id/)
      expect { Zerobounce.export_sftp_file(file_id: 'fid', export_path: ' ') }
        .to raise_error(ArgumentError, /export_path/)

      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})
    end
  end

  describe 'list evaluator' do
    it 'uses its own base URL and encodes the file id as one path segment' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/listevaluator/})
        .to_return(status: 200, body: '{"success":true}',
                   headers: { 'Content-Type' => 'application/json' })

      Zerobounce.get_list_evaluator_result('a b/c')
      expect(last_request.uri.to_s).to include('/v2/listevaluator/a%20b%2Fc/')
    end

    it 'rejects a blank file id before any request' do
      expect { Zerobounce.get_list_evaluator_result('  ') }.to raise_error(ArgumentError, /file_id/)
      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})
    end
  end

  describe 'Inbox Placement Tester' do
    before do
      stub_request(:any, %r{\Ahttps://bulkapi\.zerobounce\.net/api/ipt})
        .to_return(status: 200, body: '{"ok":true}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'uses its own host and puts the API key on the query string' do
      Zerobounce.inbox_placement_providers
      expect(last_request.uri.path).to eq('/api/ipt/providers')
      expect(last_query['api_key']).to eq(api_key)

      Zerobounce.inbox_placement_test_types
      expect(last_request.uri.path).to eq('/api/ipt/test-types')
    end

    it 'sends camelCase JSON and leaves unset fields out' do
      Zerobounce.create_inbox_placement_test('Launch', test_type: 1,
                                                       sender_email: 'news@example.com',
                                                       webhook_url: 'https://example.com/ipt')
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.path).to eq('/api/ipt/test')
      expect(JSON.parse(last_request.body)).to eq(
        'name' => 'Launch',
        'testType' => 1,
        'senderEmail' => 'news@example.com',
        'webhookUrl' => 'https://example.com/ipt'
      )
    end

    it 'sends only the list filters that are given' do
      Zerobounce.list_inbox_placement_tests(status: 'finished', page: 1, page_size: 25)
      expect(last_query).to include('status' => 'finished', 'page' => '1', 'pageSize' => '25')

      Zerobounce.list_inbox_placement_tests
      expect(last_query.keys).to eq(['api_key'])
    end

    it 'deletes a test and sets the webhook' do
      Zerobounce.delete_inbox_placement_test('a b/c')
      expect(last_request.method).to eq(:delete)
      expect(last_request.uri.to_s).to include('/api/ipt/test/a%20b%2Fc')

      Zerobounce.set_inbox_placement_webhook('https://example.com/ipt')
      expect(last_request.method).to eq(:put)
      expect(JSON.parse(last_request.body)).to eq('webhookUrl' => 'https://example.com/ipt')
    end

    it 'rejects blank arguments before any request' do
      expect { Zerobounce.inbox_placement_test('  ') }.to raise_error(ArgumentError, /test_id/)
      expect { Zerobounce.create_inbox_placement_test(' ') }.to raise_error(ArgumentError, /name/)
      expect { Zerobounce.set_inbox_placement_webhook('') }.to raise_error(ArgumentError, /webhook_url/)
      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})
    end

    it 'surfaces a "detail" error body' do
      # The Tester is a Django REST framework app: it reports errors under
      # "detail" rather than the "error"/"message" keys the rest of the API uses.
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/api/ipt/test/123})
        .to_return(status: 200, body: '{"detail":"Inbox placement test not found."}',
                   headers: { 'Content-Type' => 'application/json' })

      expect { Zerobounce.inbox_placement_test('123') }
        .to raise_error(/Inbox placement test not found\./)
    end
  end
end
