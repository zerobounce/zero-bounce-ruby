# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe Zerobounce do
  let(:api_key) { 'dummy_key' }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  after do
    Zerobounce.config.bulk_root_url = nil
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

  describe '.send_email_finder_file' do
    let(:fixture) { File.join(Dir.pwd, 'spec', 'fixtures', 'priority3_finder.csv') }

    before do
      FileUtils.mkdir_p(File.dirname(fixture))
      File.write(fixture, "domain,first,full\nacme.com,Jane,Jane Doe\n")
    end

    it 'posts to the bulk email-finder sendfile on the bulkapi root' do
      stub_request(:post, 'https://bulkapi.zerobounce.net/email-finder/sendfile')
        .to_return(
          status: 200,
          body: '{"success":true,"file_id":"f1","file_name":"out.csv"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = Zerobounce.send_email_finder_file(fixture, domain_column: 1, first_name_column: 2)
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.host).to eq('bulkapi.zerobounce.net')
      expect(last_request.uri.path).to eq('/email-finder/sendfile')
      expect(last_request.uri.query).to be_nil
      # A multipart upload carries the key in the body, not the query string.
      expect(last_request.body).to include('name="api_key"', api_key)
      expect(last_request.body).to include('name="domain_column"', 'name="first_name_column"')
      expect(result['success']).to be true
      expect(result['file_id']).to eq('f1')
    end

    it 'accepts full_name_column instead of first_name_column' do
      stub_request(:post, 'https://bulkapi.zerobounce.net/email-finder/sendfile')
        .to_return(status: 200, body: '{"success":true}',
                   headers: { 'Content-Type' => 'application/json' })

      Zerobounce.send_email_finder_file(fixture, domain_column: 1, full_name_column: 3)
      expect(last_request.body).to include('name="full_name_column"')
      expect(last_request.body).not_to include('name="first_name_column"')
    end

    it 'requires one of first_name_column or full_name_column before any request' do
      # The finder has nothing to build a local part from without a name column.
      expect { Zerobounce.send_email_finder_file(fixture, domain_column: 1) }
        .to raise_error(ArgumentError, /first_name_column or full_name_column/)
      expect { Zerobounce.send_email_finder_file(fixture, domain_column: 1, first_name_column: '  ') }
        .to raise_error(ArgumentError, /first_name_column or full_name_column/)

      expect(WebMock).not_to have_requested(:any, /zerobounce\.net/)
    end

    it 'raises the error body the API sends back' do
      stub_request(:post, 'https://bulkapi.zerobounce.net/email-finder/sendfile')
        .to_return(status: 200, body: '{"success":false,"message":"Invalid API key."}',
                   headers: { 'Content-Type' => 'application/json; charset=utf-8' })

      expect { Zerobounce.send_email_finder_file(fixture, domain_column: 1, first_name_column: 2) }
        .to raise_error(/Invalid API key\./)
    end
  end

  describe '.list_s3_files' do
    it 'gets listS3files on the bulkapi root, without /v2' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/listS3files\?})
        .to_return(
          status: 200,
          body: '[{"file_name":"bucket/key.csv"}]',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = Zerobounce.list_s3_files(bucket: 'my-bucket', search: 'key')
      expect(last_request.method).to eq(:get)
      expect(last_request.uri.path).to eq('/listS3files')
      expect(last_query).to include('api_key' => api_key, 'bucket' => 'my-bucket', 'search' => 'key')
      expect(result).to be_an(Array)
      expect(result.first['file_name']).to eq('bucket/key.csv')
    end

    it 'leaves bucket and search off when they are not given' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/listS3files\?})
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      expect(Zerobounce.list_s3_files).to eq([])
      expect(last_query.keys).to eq(['api_key'])
    end

    it 'raises an error body instead of returning it' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/listS3files\?})
        .to_return(status: 200, body: '{"error":"Invalid API key."}',
                   headers: { 'Content-Type' => 'application/json' })

      expect { Zerobounce.list_s3_files }.to raise_error(/Invalid API key\./)
    end
  end

  describe '.validate_s3_file and .score_s3_file' do
    before do
      stub_request(:post, %r{\Ahttps://bulkapi\.zerobounce\.net/(validate|score)S3file})
        .to_return(status: 200, body: '{"success":true,"file_id":"fid"}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'posts the same job shape as the other S3 and SFTP jobs' do
      result = Zerobounce.validate_s3_file(file_name: 'bucket/key.csv', has_header_row: true,
                                           return_url: 'https://example.com/done',
                                           remove_duplicates: true)
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.host).to eq('bulkapi.zerobounce.net')
      expect(last_request.uri.path).to eq('/validateS3file')
      # The key travels in the form body, not a query string that gets logged.
      expect(last_request.uri.query).to be_nil
      # A form POST carries the key in the body, not the query string.
      expect(last_form).to include(
        'api_key' => api_key,
        'file_name' => 'bucket/key.csv',
        'has_header_row' => 'true',
        'remove_duplicates' => 'true',
        'return_url' => 'https://example.com/done'
      )
      expect(result['file_id']).to eq('fid')
    end

    it 'posts scoreS3file to its own path and leaves unset options off' do
      Zerobounce.score_s3_file(file_name: 'bucket/key.csv', return_url: 'https://example.com/done')
      expect(last_request.uri.path).to eq('/scoreS3file')
      expect(last_form).to include('has_header_row' => 'false')
      expect(last_form).not_to have_key('remove_duplicates')
    end

    it 'requires file_name and return_url before any request' do
      # LIVE: the API answers "This field is required" without either, the same
      # as it does for the S3 and SFTP jobs these now share a helper with.
      %i[validate_s3_file score_s3_file].each do |method|
        expect { Zerobounce.public_send(method, file_name: '  ', return_url: 'https://example.com/done') }
          .to raise_error(ArgumentError, /file_name/)
        expect { Zerobounce.public_send(method, file_name: 'bucket/key.csv') }
          .to raise_error(ArgumentError, /return_url/)
        expect { Zerobounce.public_send(method, file_name: 'bucket/key.csv', return_url: ' ') }
          .to raise_error(ArgumentError, /return_url/)
      end

      expect(WebMock).not_to have_requested(:any, /zerobounce\.net/)
    end
  end

  describe '.export_s3_file' do
    before do
      stub_request(:post, 'https://bulkapi.zerobounce.net/exportS3file')
        .to_return(status: 200, body: '{"success":true}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends export_bucket when it is given' do
      Zerobounce.export_s3_file(file_id: 'fid', export_bucket: 'my-bucket')
      expect(last_request.method).to eq(:post)
      expect(last_request.uri.host).to eq('bulkapi.zerobounce.net')
      expect(last_request.uri.path).to eq('/exportS3file')
      expect(last_form).to include('api_key' => api_key, 'file_id' => 'fid', 'export_bucket' => 'my-bucket')
    end

    it 'leaves export_bucket out when it is absent, falling back to account settings' do
      result = Zerobounce.export_s3_file(file_id: 'fid')
      expect(last_form).to include('file_id' => 'fid')
      expect(last_form).not_to have_key('export_bucket')
      expect(result['success']).to be true
    end

    it 'rejects a blank file_id or a blank export_bucket before any request' do
      expect { Zerobounce.export_s3_file(file_id: '  ') }.to raise_error(ArgumentError, /file_id/)
      expect { Zerobounce.export_s3_file(file_id: 'fid', export_bucket: ' ') }
        .to raise_error(ArgumentError, /export_bucket/)

      expect(WebMock).not_to have_requested(:any, /zerobounce\.net/)
    end
  end

  describe 'a JSON content type with parameters' do
    # The API types some responses 'application/json; charset=utf-8'. Compared
    # with ==, those skipped JSON parsing and an error payload came back as a
    # plain String that read as a success.
    it 'is parsed as JSON on the bulk /v2 endpoints' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/filestatus})
        .to_return(status: 200, body: '{"success":true,"file_id":"fid","complete_percentage":"100%"}',
                   headers: { 'Content-Type' => 'application/json; charset=utf-8' })

      result = Zerobounce.validate_file_check('fid')
      expect(result).to be_a(Hash)
      expect(result['complete_percentage']).to eq('100%')
    end

    it 'raises a bulk /v2 error body instead of returning it as a String' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/filestatus})
        .to_return(status: 200, body: '{"success":false,"message":"File cannot be found."}',
                   headers: { 'Content-Type' => 'application/json; charset=utf-8' })

      expect { Zerobounce.validate_file_check('fid') }.to raise_error(/File cannot be found/)
    end

    it 'raises a bulkapi root error body instead of returning it as a String' do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/email-finder/filestatus\?})
        .to_return(status: 200, body: '{"error":"File cannot be found."}',
                   headers: { 'Content-Type' => 'APPLICATION/JSON; charset=UTF-8' })

      expect { Zerobounce.email_finder_file_status('fid') }.to raise_error(/File cannot be found/)
    end
  end

  describe 'bulk_root_url configuration' do
    it 'is derived from bulk_api_root_url when it is not set' do
      expect(Zerobounce.config.bulk_root_url).to be_nil

      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/listS3files\?})
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      Zerobounce.list_s3_files
      expect(last_request.uri.host).to eq('bulkapi.zerobounce.net')
      expect(last_request.uri.path).to eq('/listS3files')
    end

    it 'points the S3 and SFTP jobs elsewhere when it is set' do
      Zerobounce.config.bulk_root_url = 'https://bulk-mock.example.com/'

      stub_request(:get, %r{\Ahttps://bulk-mock\.example\.com/listS3files\?})
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, 'https://bulk-mock.example.com/exportS3file')
        .to_return(status: 200, body: '{"success":true}',
                   headers: { 'Content-Type' => 'application/json' })

      Zerobounce.list_s3_files
      expect(last_request.uri.host).to eq('bulk-mock.example.com')
      expect(last_request.uri.path).to eq('/listS3files')

      Zerobounce.export_s3_file(file_id: 'fid')
      expect(last_request.uri.host).to eq('bulk-mock.example.com')
      expect(last_request.uri.path).to eq('/exportS3file')
    end

    it 'leaves the /v2 bulk endpoints alone' do
      Zerobounce.config.bulk_root_url = 'https://bulk-mock.example.com/'

      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/filestatus})
        .to_return(status: 200, body: '{"success":true,"file_id":"fid"}',
                   headers: { 'Content-Type' => 'application/json' })

      Zerobounce.validate_file_check('fid')
      expect(last_request.uri.host).to eq('bulkapi.zerobounce.net')
      expect(last_request.uri.path).to eq('/v2/filestatus')
    end
  end

  describe 'the email finder (GET /guessformat)' do
    before do
      stub_request(:get, %r{\Ahttps://api\.zerobounce\.net/v2/guessformat})
        .to_return(
          status: 200,
          body: '{"email":"john@zerobounce.net","email_confidence":"medium",' \
                '"domain":"zerobounce.net","company_name":"ZeroBounce",' \
                '"did_you_mean":"","failure_reason":""}',
          headers: { 'Content-Type' => 'application/json; charset=utf-8' }
        )
    end

    describe '.find_email' do
      it 'sends first_name and the names that are given' do
        result = Zerobounce.find_email('John', domain: 'zerobounce.net', middle_name: 'Deere', last_name: 'Doe')
        expect(last_request.method).to eq(:get)
        expect(last_request.uri.path).to eq('/v2/guessformat')
        expect(last_query).to eq(
          'api_key' => api_key,
          'first_name' => 'John',
          'domain' => 'zerobounce.net',
          'middle_name' => 'Deere',
          'last_name' => 'Doe'
        )
        expect(result['email']).to eq('john@zerobounce.net')
      end

      it 'works without a first name' do
        # The endpoint only requires a domain or a company name; a first name
        # narrows the answer to one person but is not required.
        Zerobounce.find_email(domain: 'zerobounce.net')
        expect(last_query).to eq('api_key' => api_key, 'domain' => 'zerobounce.net')

        Zerobounce.find_email(nil, company_name: 'Zero Bounce', last_name: 'Doe')
        expect(last_query).to eq('api_key' => api_key, 'company_name' => 'Zero Bounce', 'last_name' => 'Doe')
      end

      it 'still requires exactly one of domain or company_name' do
        expect { Zerobounce.find_email }
          .to raise_error(ArgumentError, /Either domain or company_name must be provided/)
        expect { Zerobounce.find_email('John') }
          .to raise_error(ArgumentError, /Either domain or company_name must be provided/)
        expect { Zerobounce.find_email(domain: 'zerobounce.net', company_name: 'Zero Bounce') }
          .to raise_error(ArgumentError, /Only one of domain or company_name can be provided/)

        expect(WebMock).not_to have_requested(:any, /zerobounce\.net/)
      end

      it 'raises the error body the API sends back' do
        stub_request(:get, %r{\Ahttps://api\.zerobounce\.net/v2/guessformat})
          .to_return(status: 200, body: '{"error":"Invalid API key or your account ran out of credits"}',
                     headers: { 'Content-Type' => 'application/json; charset=utf-8' })

        expect { Zerobounce.find_email(domain: 'zerobounce.net') }
          .to raise_error(/Invalid API key or your account ran out of credits/)
      end
    end

    describe '.find_domain' do
      it 'sends no name fields at all' do
        Zerobounce.find_domain(domain: 'zerobounce.net')
        expect(last_query).to eq('api_key' => api_key, 'domain' => 'zerobounce.net')

        Zerobounce.find_domain(company_name: 'Zero Bounce')
        expect(last_query).to eq('api_key' => api_key, 'company_name' => 'Zero Bounce')
      end

      it 'still requires exactly one of domain or company_name' do
        expect { Zerobounce.find_domain }
          .to raise_error(ArgumentError, /Either domain or company_name must be provided/)
        expect { Zerobounce.find_domain(domain: 'zerobounce.net', company_name: 'Zero Bounce') }
          .to raise_error(ArgumentError, /Only one of domain or company_name can be provided/)
      end
    end

    describe '.guessformat' do
      it 'keeps its deprecated positional domain and name options' do
        expect { Zerobounce.guessformat('zerobounce.net', first_name: 'John', last_name: 'Doe') }
          .to output(/deprecated/).to_stderr
        expect(last_query).to eq(
          'api_key' => api_key,
          'domain' => 'zerobounce.net',
          'first_name' => 'John',
          'last_name' => 'Doe'
        )
      end
    end
  end
end
