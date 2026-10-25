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
      Zerobounce.email_finder_s3_file('lists/leads.csv', true,
                                      return_url: 'https://example.com/done')
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.path).to eq('/emailFinderS3file')
      expect(last_form).to include('file_name' => 'lists/leads.csv', 'has_header_row' => 'true',
                                   'return_url' => 'https://example.com/done')
      # Unset options stay off the request entirely.
      expect(last_form).not_to have_key('remove_duplicates')
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

    it 'requires file_name on validateSFTPfile too' do
      # LIVE: the docs list it as optional for this one endpoint, but the API
      # answers "This field is required" without it.
      expect do
        Zerobounce.validate_sftp_file(nil, true, return_url: 'https://example.com/done')
      end.to raise_error(ArgumentError, /file_name/)

      Zerobounce.validate_sftp_file('my_file.txt', true, return_url: 'https://example.com/done')
      expect(last_request.uri.path).to eq('/validateSFTPfile')
      expect(last_form['file_name']).to eq('my_file.txt')
      expect(last_form['has_header_row']).to eq('true')
    end

    it 'requires return_url on every job' do
      # LIVE: without it the API answers "This field is required".
      %i[email_finder_s3_file domain_search_s3_file validate_sftp_file
         score_sftp_file email_finder_sftp_file domain_search_sftp_file].each do |method|
        expect do
          Zerobounce.public_send(method, 'f.csv', true)
        end.to raise_error(ArgumentError, /return_url/)
      end
    end

    it 'posts each remaining job to its documented path' do
      {
        'scoreSFTPfile' => :score_sftp_file,
        'emailFinderSFTPfile' => :email_finder_sftp_file,
        'domainSearchSFTPfile' => :domain_search_sftp_file
      }.each do |path, method|
        Zerobounce.public_send(method, 'my_file.txt', true, return_url: 'https://example.com/done')
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

  describe 'filters' do
    it 'treats a bare Message body as the success the API means it to be' do
      # LIVE: /filters/add answers a success with {"Message": "Filter
      # successfully added"}, the same shape the validate endpoints use for a
      # rejected request.
      stub_request(:post, %r{\Ahttps://api\.zerobounce\.net/v2/filters/add})
        .to_return(status: 200, body: '{"Message":"Filter successfully added"}',
                   headers: { 'Content-Type' => 'application/json' })

      result = Zerobounce.add_filter(rule: 'allow', target: 'domain', value: 'example.com')
      expect(result).to eq('Message' => 'Filter successfully added')
    end

    it 'still treats a bare Message body on validate as an error' do
      stub_request(:get, %r{\Ahttps://api\.zerobounce\.net/v2/validate})
        .to_return(status: 200, body: '{"Message":"Missing parameter: email."}',
                   headers: { 'Content-Type' => 'application/json' })

      expect { Zerobounce.validate('a@example.com') }.to raise_error(/Missing parameter/)
    end
  end

  describe 'success:false on an HTTP 200' do
    it 'is an error, not a result' do
      # LIVE: the API answers an unknown bulk file id with an HTTP 200 whose
      # body says the call failed.
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/filestatus})
        .to_return(status: 200, body: '{"success":false,"message":"File cannot be found."}',
                   headers: { 'Content-Type' => 'application/json' })

      expect do
        Zerobounce.validate_file_check('0d1b7a4e-1111-2222-3333-444455556666')
      end.to raise_error(/File cannot be found/)
    end
  end

  describe 'Inbox Placement Tester' do
    before do
      stub_request(:any, %r{\Ahttps://bulkapi\.zerobounce\.net/api/ipt})
        .to_return(status: 200, body: '{"ok":true}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'uses its own host and authenticates with a Bearer header' do
      Zerobounce.inbox_placement_providers
      expect(last_request.uri.path).to eq('/api/ipt/providers')
      # LIVE: the key goes in an Authorization header, not a query parameter
      # that gets logged.
      expect(last_request.headers['Authorization']).to eq("Bearer #{api_key}")
      expect(last_query).not_to have_key('api_key')

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
      Zerobounce.list_inbox_placement_tests(status: 'finished', page: 1, page_size: 25,
                                            created_after: '2026-01-01', created_before: '2026-02-01')
      # LIVE: the listing is GET /tests (plural); /test answers
      # 'Method "GET" not allowed'.
      expect(last_request.uri.path).to eq('/api/ipt/tests')
      # LIVE: the page size parameter is page_size. pageSize is accepted and
      # then ignored - page_size=1 paginates, pageSize=1 returns the full list.
      expect(last_query).to include('status' => 'finished', 'page' => '1', 'page_size' => '25',
                                    'createdAfter' => '2026-01-01', 'createdBefore' => '2026-02-01')
      expect(last_query).not_to have_key('pageSize')

      Zerobounce.list_inbox_placement_tests
      expect(last_query.keys).to eq([])
    end

    it 'bounds page_size to 1-100 before any request' do
      [0, -1, 101, 'many'].each do |page_size|
        expect { Zerobounce.list_inbox_placement_tests(page_size: page_size) }
          .to raise_error(ArgumentError, /page_size must be between 1 and 100/)
      end
      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})

      [1, 100].each do |page_size|
        Zerobounce.list_inbox_placement_tests(page_size: page_size)
        expect(last_query).to include('page_size' => page_size.to_s)
      end
    end

    it 'enforces the documented bounds on a new test before it spends credits' do
      expect { Zerobounce.create_inbox_placement_test('n' * 65) }
        .to raise_error(ArgumentError, /64 characters/)
      expect { Zerobounce.create_inbox_placement_test('Launch', test_type: 4) }
        .to raise_error(ArgumentError, /test_type must be one of 1, 2, 3/)
      expect { Zerobounce.create_inbox_placement_test('Launch', test_type: 0) }
        .to raise_error(ArgumentError, /test_type must be one of 1, 2, 3/)
      # testType 1 is the seed-list test, which has nowhere to send from
      # without a sender address.
      expect { Zerobounce.create_inbox_placement_test('Launch', test_type: 1) }
        .to raise_error(ArgumentError, /sender_email is required when test_type is 1/)
      expect { Zerobounce.create_inbox_placement_test('Launch', test_type: 1, sender_email: ' ') }
        .to raise_error(ArgumentError, /sender_email is required when test_type is 1/)

      expect(WebMock).not_to have_requested(:any, %r{zerobounce\.net})

      # A name of exactly 64 and the test types that need no sender are fine.
      Zerobounce.create_inbox_placement_test('n' * 64, test_type: 2)
      expect(JSON.parse(last_request.body)).to eq('name' => 'n' * 64, 'testType' => 2)
      Zerobounce.create_inbox_placement_test('Launch', test_type: 3)
      expect(JSON.parse(last_request.body)).to eq('name' => 'Launch', 'testType' => 3)
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
