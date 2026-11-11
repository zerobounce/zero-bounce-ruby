# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength, Naming/VariableNumber
# The behaviour every ZeroBounce SDK shares for the same API response
# (sdk-docs standard, section 3). Every request is stubbed with WebMock.
describe 'Behaviour shared with the other SDKs' do
  let(:api_key) { 'parity-key' }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  def answer(body, status: 200, headers: json)
    stub_request(:any, /.*/).to_return(status: status, body: body, headers: headers)
  end

  def last_request
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
  end

  describe 'the greylist answer on validate' do
    let(:greylist) { '{"Message":"Greylist validation still in progress..."}' }

    it 'is a result on GET, with its text on the response' do
      answer(greylist)
      result = Zerobounce.validate('a@example.com', greylist_processing: true)
      expect(result).to eq('Message' => 'Greylist validation still in progress...')
    end

    it 'is a result on POST' do
      answer(greylist)
      result = Zerobounce.validate('a@example.com', greylist_processing: true, use_post: true)
      expect(result['Message']).to eq('Greylist validation still in progress...')
    end
  end

  describe 'a 2xx error body without "success"' do
    it 'raises for error_message on credits, with status 200' do
      answer('{"error_message":"Invalid API key"}')
      expect { Zerobounce.credits }.to raise_error(Zerobounce::ApiResponseError, 'Invalid API key') { |e|
        expect(e.status_code).to eq(200)
        expect(e).to be_a(RuntimeError)
      }
    end

    it 'raises for error_message on validate' do
      answer('{"error_message":"Invalid API key"}')
      expect { Zerobounce.validate('a@example.com') }.to raise_error(RuntimeError, 'Invalid API key')
    end

    it 'raises for error_message on a bulk status call' do
      answer('{"error_message":"Invalid API key"}')
      expect { Zerobounce.validate_file_check('f1') }.to raise_error(RuntimeError, 'Invalid API key')
    end

    it 'raises for error_message on the bulk root' do
      answer('{"error_message":"Invalid API key"}')
      expect { Zerobounce.email_finder_file_status('f1') }.to raise_error(RuntimeError, 'Invalid API key')
    end

    it 'carries status 200 for a dead key on validate' do
      answer('{"error":"Invalid API key or your account ran out of credits"}')
      expect { Zerobounce.validate('a@example.com') }.to raise_error(Zerobounce::ApiResponseError) { |e|
        expect(e.status_code).to eq(200)
      }
    end

    it 'is a result when "success" is present' do
      answer('{"success":true,"error_message":""}')
      expect(Zerobounce.validate_file_check('f1')).to eq('success' => true, 'error_message' => '')
    end
  end

  describe 'message-only bodies on the email finder and domain search' do
    {
      '{"Message":"Invalid API key or your account ran out of credits"}' =>
        'Invalid API key or your account ran out of credits',
      '{"detail":"Not allowed"}' => 'Not allowed',
      '{"error_message":"Not allowed"}' => 'Not allowed',
      '{"message":"Not allowed"}' => 'Not allowed'
    }.each do |body, message|
      it "raise for #{body}" do
        answer(body)
        expect { Zerobounce.find_domain(domain: 'example.com') }.to raise_error(RuntimeError, message)
        expect { Zerobounce.find_email('Ann', domain: 'example.com') }.to raise_error(RuntimeError, message)
      end
    end

    it 'leave a body with other fields alone' do
      answer('{"domain":"example.com","format":"first.last","Message":""}')
      expect(Zerobounce.find_domain(domain: 'example.com')['format']).to eq('first.last')
    end
  end

  describe 'bulk responses' do
    it 'treat an empty "error" as no error' do
      answer('{"success":true,"file_status":"Complete","error":""}')
      expect(Zerobounce.validate_file_check('f1')['file_status']).to eq('Complete')
    end

    it 'raise for an empty getfile body' do
      answer('', headers: { 'Content-Type' => 'application/octet-stream' })
      expect { Zerobounce.validate_file_get('f1') }.to raise_error(Zerobounce::ApiResponseError, /Empty response/)
    end
  end

  describe 'API keys' do
    ["key\n", ' key', "ke\ty", "key\u007f"].each do |bad|
      it "rejects #{bad.inspect} before sending anything" do
        Zerobounce.config.apikey = bad
        expect { Zerobounce.credits }.to raise_error(ArgumentError, /whitespace or control/)
        expect { Zerobounce.get_list_evaluator_result('f1') }.to raise_error(ArgumentError, /whitespace or control/)
        expect { Zerobounce.inbox_placement_providers }.to raise_error(ArgumentError, /whitespace or control/)
        expect(WebMock).not_to have_requested(:any, /.*/)
      end

      it "rejects #{bad.inspect} in Zerobounce::Client" do
        expect { Zerobounce::Client.new(bad) }.to raise_error(ArgumentError, /whitespace or control/)
      end
    end

    it 'rejects a bad key passed to with_api_key' do
      expect { Zerobounce.with_api_key("key\n") { Zerobounce.credits } }.to raise_error(ArgumentError)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it 'keeps the key out of #inspect' do
      client = Zerobounce::Client.new('secret-client-key')
      warmup = Zerobounce::Warmup.new('secret-warmup-key')
      expect(client.inspect).not_to include('secret-client-key')
      expect(warmup.inspect).not_to include('secret-warmup-key')
      expect(client.inspect).to include('Zerobounce::Client')
      expect(warmup.inspect).to include('Zerobounce::Warmup')
    end
  end

  describe 'boolean options' do
    before { answer('{"address":"a@example.com","status":"valid","success":true}') }

    def sent
      query = URI.decode_www_form(last_request.uri.query.to_s).to_h
      body = last_request.body.to_s
      return query.merge(JSON.parse(body).transform_values(&:to_s)) if body.start_with?('{')

      query.merge(URI.decode_www_form(body).to_h)
    end

    it "send 'false' as false and 'TRUE' or 1 as true" do
      Zerobounce.validate('a@example.com', activity_data: 'false', verify_plus: 'TRUE', domain_info: 0,
                                           greylist_processing: 1)
      expect(sent).to include('activity_data' => 'false', 'verify_plus' => 'true', 'domain_info' => 'false',
                              'greylist_processing' => 'true')
    end

    it 'reject anything else on validate' do
      expect { Zerobounce.validate('a@example.com', activity_data: 'yes') }
        .to raise_error(ArgumentError, /activity_data must be true or false/)
      expect { Zerobounce.validate('a@example.com', greylist_processing: 2) }.to raise_error(ArgumentError)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it 'are JSON booleans on validate_batch' do
      answer('{"email_batch":[],"errors":[]}')
      Zerobounce.validate_batch(['a@example.com'], activity_data: 'false')
      expect(JSON.parse(last_request.body)['activity_data']).to be(false)
      expect { Zerobounce.validate_batch(['a@example.com'], verify_plus: 'nope') }.to raise_error(ArgumentError)
    end

    it "send 'false' as false on the S3 and SFTP jobs" do
      Zerobounce.validate_s3_file(file_name: 'f.csv', has_header_row: 'false', remove_duplicates: 'false',
                                  return_url: 'https://example.com/done')
      expect(sent).to include('has_header_row' => 'false', 'remove_duplicates' => 'false')
    end

    it 'reject junk on the S3 and SFTP jobs' do
      expect do
        Zerobounce.validate_s3_file(file_name: 'f.csv', has_header_row: 'yes', return_url: 'https://example.com/done')
      end.to raise_error(ArgumentError, /has_header_row/)
      expect do
        Zerobounce.email_finder_sftp_file('f.csv', true, remove_duplicates: 'nope', return_url: 'https://example.com/d')
      end.to raise_error(ArgumentError, /remove_duplicates/)
      expect { Zerobounce.score_sftp_file('f.csv', nil, return_url: 'https://example.com/d') }
        .to raise_error(ArgumentError, /has_header_row/)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it 'reject junk on file uploads and downloads' do
      file = 'spec/fixtures/priority3_finder.csv'
      expect { Zerobounce.validate_file_send(file, has_header_row: 'yes') }.to raise_error(ArgumentError)
      expect { Zerobounce.validate_file_send(file, allow_phase_2: 'maybe') }.to raise_error(ArgumentError)
      expect { Zerobounce.send_domain_search_file(file, domain_column: 1, has_header_row: 'y') }
        .to raise_error(ArgumentError)
      options = Zerobounce::GetFileOptions.new
      options.activity_data = 'nope'
      expect { Zerobounce.validate_file_get('f1', options) }.to raise_error(ArgumentError)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end

  # Every public request method refuses to send the key to a non-https URL.
  describe 'HTTPS sweep' do
    file = 'spec/fixtures/priority3_finder.csv'
    calls = {
      validate: [['a@example.com']],
      credits: [[]],
      api_usage: [[Date.new(2024, 1, 1), Date.new(2024, 1, 2)]],
      activity: [['a@example.com']],
      score_email: [['a@example.com']],
      validate_batch: [[['a@example.com']]],
      validate_file_send: [[file]],
      validate_file_send_stream: [[StringIO.new("email\na@example.com\n"), 'f.csv']],
      validate_file_check: [['f1']],
      validate_file_get: [['f1']],
      validate_file_delete: [['f1']],
      scoring_file_send: [[file]],
      scoring_file_send_stream: [[StringIO.new("email\na@example.com\n"), 'f.csv']],
      scoring_file_get: [['f1']],
      scoring_file_check: [['f1']],
      scoring_file_delete: [['f1']],
      guessformat: [['example.com']],
      find_email: [['Ann'], { domain: 'example.com' }],
      find_domain: [[], { domain: 'example.com' }],
      send_email_finder_file: [[file], { domain_column: 1, first_name_column: 2 }],
      email_finder_file_status: [['f1']],
      email_finder_file_get: [['f1']],
      email_finder_file_delete: [['f1']],
      send_domain_search_file: [[file], { domain_column: 1 }],
      domain_search_file_status: [['f1']],
      domain_search_file_get: [['f1']],
      domain_search_file_delete: [['f1']],
      send_list_evaluator_file: [[file], { email_address_column: 1 }],
      get_list_evaluator_result: [['f1']],
      send_evaluated_file: [['f1']],
      add_filter: [[], { rule: 'allow', target: 'email', value: 'a@example.com' }],
      list_filters: [[]],
      delete_filter: [[], { rule: 'allow', target: 'email', value: 'a@example.com' }],
      list_s3_files: [[]],
      validate_s3_file: [[], { file_name: 'f.csv', return_url: 'https://example.com/d' }],
      score_s3_file: [[], { file_name: 'f.csv', return_url: 'https://example.com/d' }],
      export_s3_file: [[], { file_id: 'f1' }],
      email_finder_s3_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      domain_search_s3_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      validate_sftp_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      score_sftp_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      email_finder_sftp_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      domain_search_sftp_file: [['f.csv', true], { return_url: 'https://example.com/d' }],
      export_sftp_file: [[], { file_id: 'f1' }],
      inbox_placement_providers: [[]],
      inbox_placement_test_types: [[]],
      create_inbox_placement_test: [['Test'], { test_type: 2 }],
      inbox_placement_test: [['1']],
      list_inbox_placement_tests: [[]],
      delete_inbox_placement_test: [['1']],
      inbox_placement_webhook: [[]],
      set_inbox_placement_webhook: [['https://example.com/hook']]
    }
    not_requests = %i[configuration config configure configuration= with_api_key
                      get_file_json_indicates_error? zb_request]

    around do |example|
      saved = Zerobounce.configuration
      Zerobounce.configuration = Zerobounce::Configuration.new
      example.run
    ensure
      Zerobounce.configuration = saved
    end

    before do
      Zerobounce.configure do |c|
        c.apikey = api_key
        c.api_root_url = 'http://api.example.test/v2'
        c.bulk_api_root_url = 'http://bulk.example.test/v2'
        c.bulk_root_url = 'http://bulk.example.test'
        c.list_evaluator_root_url = 'http://bulk.example.test/v2/listevaluator'
        c.inbox_placement_root_url = 'http://bulk.example.test/api/ipt'
      end
      allow(Zerobounce).to receive(:warn)
    end

    it 'covers every public request method' do
      expect(Zerobounce.singleton_methods.sort - not_requests - calls.keys).to eq([])
    end

    calls.each do |name, (args, kwargs)|
      it "refuses http for #{name}" do
        expect { Zerobounce.public_send(name, *args, **(kwargs || {})) }
          .to raise_error(ArgumentError, %r{https://})
        expect(WebMock).not_to have_requested(:any, /.*/)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength, Naming/VariableNumber
