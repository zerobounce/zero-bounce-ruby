# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength, Lint/ConstantDefinitionInBlock
# Error answers and argument checks, every request stubbed with WebMock.
describe 'Errors and argument checks' do
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:email_file) { File.join(__dir__, 'fixtures', 'priority3_finder.csv') }

  before { Zerobounce.configure { |c| c.apikey = 'errors-spec-key' } }

  def answer(body, status: 200)
    stub_request(:any, /.*/).to_return(status: status, body: body, headers: json)
  end

  # Every typed call that goes through the shared JSON handling, except validate's
  # greylist and the exempt families (see EXEMPT).
  TYPED = {
    'validate' => -> { Zerobounce.validate('a@example.com') },
    'validate POST' => -> { Zerobounce.validate('a@example.com', use_post: true) },
    'credits' => -> { Zerobounce.credits },
    'api_usage' => -> { Zerobounce.api_usage(Date.new(2024, 1, 1), Date.new(2024, 1, 2)) },
    'activity' => -> { Zerobounce.activity('a@example.com') },
    'score_email' => -> { Zerobounce.score_email('a@example.com') },
    'validate_batch' => -> { Zerobounce.validate_batch(['a@example.com']) },
    'validate_file_send' => -> { Zerobounce.validate_file_send(File.join('spec', 'fixtures', 'priority3_finder.csv')) },
    'validate_file_check' => -> { Zerobounce.validate_file_check('id') },
    'validate_file_delete' => -> { Zerobounce.validate_file_delete('id') },
    'scoring_file_send' => -> { Zerobounce.scoring_file_send(File.join('spec', 'fixtures', 'priority3_finder.csv')) },
    'scoring_file_check' => -> { Zerobounce.scoring_file_check('id') },
    'scoring_file_delete' => -> { Zerobounce.scoring_file_delete('id') },
    'find_email' => -> { Zerobounce.find_email('John', domain: 'example.com') },
    'find_domain' => -> { Zerobounce.find_domain(domain: 'example.com') },
    'send_evaluated_file' => -> { Zerobounce.send_evaluated_file('id') },
    'send_list_evaluator_file' => lambda {
      path = File.join('spec', 'fixtures', 'priority3_finder.csv')
      Zerobounce.send_list_evaluator_file(path, email_address_column: 1)
    },
    'email_finder_file_status' => -> { Zerobounce.email_finder_file_status('id') },
    'domain_search_file_delete' => -> { Zerobounce.domain_search_file_delete('id') },
    'validate_s3_file' => -> { Zerobounce.validate_s3_file(file_name: 'f.csv', return_url: 'https://e.com/cb') },
    'export_sftp_file' => -> { Zerobounce.export_sftp_file(file_id: 'id') },
    'list_s3_files' => -> { Zerobounce.list_s3_files }
  }.freeze

  describe 'a message-only body' do
    ['{"message":"Bad thing"}', '{"Message":"Bad thing"}', '{"error_message":"Bad thing"}',
     '{"detail":"Bad thing"}'].each do |body|
      TYPED.each do |name, call|
        # validate's greylist answer is {"Message": "..."}: a result.
        next if name.start_with?('validate') && !name.include?('_') && body == '{"Message":"Bad thing"}'

        it "is an error with status 200 on #{name}: #{body}" do
          answer(body)
          expect { instance_exec(&call) }.to raise_error(Zerobounce::ApiResponseError, 'Bad thing') { |e|
            expect(e.status_code).to eq(200)
          }
        end
      end
    end

    it 'joins a list of messages with a line break' do
      answer('{"Message":["a","b"]}')
      expect { Zerobounce.activity('a@example.com') }.to raise_error(Zerobounce::ApiResponseError, "a\nb")
    end

    it 'uses the fixed text for a message that is not text' do
      answer('{"message":{"a":1}}')
      expect { Zerobounce.activity('a@example.com') }
        .to raise_error(Zerobounce::ApiResponseError, 'ZeroBounce returned an error with no message text.')
    end
  end

  describe 'an empty object' do
    TYPED.each do |name, call|
      next if name == 'list_s3_files'

      it "is an error with status 200 on #{name}" do
        answer('{}')
        expect { instance_exec(&call) }.to raise_error(Zerobounce::ApiResponseError) { |e|
          expect(e.status_code).to eq(200)
        }
      end
    end
  end

  describe 'the exempt calls' do
    it 'keeps validate greylist answer a result' do
      answer('{"Message":"Greylist validation still in progress..."}')
      expect(Zerobounce.validate('a@example.com')).to eq('Message' => 'Greylist validation still in progress...')
    end

    it 'keeps the filters calls raw' do
      answer('{"Message":"Filter successfully added"}')
      expect(Zerobounce.add_filter(rule: 'a', target: 'b', value: 'c')).to eq('Message' => 'Filter successfully added')
      expect(Zerobounce.delete_filter(rule: 'a', target: 'b', value: 'c')).to be_a(Hash)
      answer('{}')
      expect(Zerobounce.add_filter(rule: 'a', target: 'b', value: 'c')).to eq({})
    end

    it 'keeps the list evaluator result a result' do
      answer('{"message":"Still working"}')
      expect(Zerobounce.get_list_evaluator_result('id')).to eq('message' => 'Still working')
    end

    it 'passes every Inbox Placement call through' do
      answer('{"message":"hi"}')
      expect(Zerobounce.inbox_placement_providers).to eq('message' => 'hi')
      expect(Zerobounce.inbox_placement_webhook).to eq('message' => 'hi')
      answer('{}')
      expect(Zerobounce.inbox_placement_test_types).to eq({})
    end
  end

  describe 'message text' do
    it 'joins a Message list on a 200' do
      answer('{"success":false,"Message":["a","b"]}')
      expect { Zerobounce.validate_file_check('id') }.to raise_error(Zerobounce::ApiResponseError, "a\nb")
    end

    it 'joins a list in a 400 body' do
      answer('{"message":["x","y"]}', status: 400)
      expect { Zerobounce.activity('a@example.com') }.to raise_error(Zerobounce::ApiResponseError, "x\ny")
    end

    it 'does not show a Ruby inspect for a non-string error' do
      answer('{"error":["x","y"]}')
      expect { Zerobounce.activity('a@example.com') }.to raise_error(Zerobounce::ApiResponseError, "x\ny")
      answer('{"error":{"a":1}}')
      expect { Zerobounce.activity('a@example.com') }
        .to raise_error(Zerobounce::ApiResponseError, 'ZeroBounce returned an error with no message text.')
      answer('{"error":{"a":1}}', status: 400)
      expect { Zerobounce.activity('a@example.com') }
        .to raise_error(Zerobounce::ApiResponseError, 'ZeroBounce returned an error with no message text.')
    end

    it 'reports an errors entry on a file call with text' do
      answer('{"errors":[{"error":["x","y"]}]}')
      expect { Zerobounce.validate_file_check('id') }.to raise_error(Zerobounce::ApiResponseError, "x\ny")
      answer('{"errors":[{"error":{"a":1}}]}')
      expect { Zerobounce.validate_file_check('id') }
        .to raise_error(Zerobounce::ApiResponseError, 'ZeroBounce returned an error with no message text.')
    end
  end

  describe 'success that reads as false' do
    [0, '0', 'false', ' False ', false].each do |value|
      it "is a failure for #{value.inspect}" do
        answer({ 'success' => value, 'message' => 'nope' }.to_json)
        expect { Zerobounce.validate_file_check('id') }.to raise_error(Zerobounce::ApiResponseError, 'nope')
      end
    end

    it 'is not a failure for true' do
      answer('{"success":true,"file_id":"x"}')
      expect(Zerobounce.validate_file_check('id')).to include('file_id' => 'x')
    end
  end

  describe 'the API invalid-key answer (HTTP 200)' do
    it 'raises on every call family' do
      answer('{"error":"Invalid API key"}')
      %w[validate credits activity score_email validate_file_check find_email].each do |name|
        label = name.tr('_', ' ')
        call = { 'validate' => TYPED['validate'], 'credits' => TYPED['credits'], 'activity' => TYPED['activity'],
                 'score_email' => TYPED['score_email'], 'validate_file_check' => TYPED['validate_file_check'],
                 'find_email' => TYPED['find_email'] }.fetch(name)
        expect { instance_exec(&call) }.to raise_error(Zerobounce::ApiResponseError, 'Invalid API key'), label
      end
      expect { Zerobounce.validate_batch(['a@example.com']) }.to raise_error(Zerobounce::ApiResponseError)
    end
  end

  describe 'arguments' do
    def no_request
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    {
      'validate(5)' => -> { Zerobounce.validate(5) },
      'validate(nil)' => -> { Zerobounce.validate(nil) },
      'validate(blank)' => -> { Zerobounce.validate('  ') },
      'validate ip 5' => -> { Zerobounce.validate('a@b.c', 5) },
      'validate timeout []' => -> { Zerobounce.validate('a@b.c', timeout: [1]) },
      'validate timeout true' => -> { Zerobounce.validate('a@b.c', timeout: true) },
      'validate timeout abc' => -> { Zerobounce.validate('a@b.c', timeout: 'abc') },
      'validate timeout 5.5' => -> { Zerobounce.validate('a@b.c', timeout: 5.5) },
      'validate timeout 2' => -> { Zerobounce.validate('a@b.c', timeout: 2) },
      'validate callback 5' => -> { Zerobounce.validate('a@b.c', greylist_processing: true, callback_url: 5) },
      'activity(nil)' => -> { Zerobounce.activity(nil) },
      'activity(5)' => -> { Zerobounce.activity(5) },
      'score_email(nil)' => -> { Zerobounce.score_email(nil) },
      'validate_batch nil ips' => nil,
      'validate_batch not array' => -> { Zerobounce.validate_batch('a') },
      'validate_batch empty' => -> { Zerobounce.validate_batch([]) },
      'validate_batch row 5' => -> { Zerobounce.validate_batch([5]) },
      'validate_batch ips string' => -> { Zerobounce.validate_batch(['a'], 'x') },
      'validate_batch ip 5' => -> { Zerobounce.validate_batch(['a'], [5]) },
      'validate_batch timeout []' => -> { Zerobounce.validate_batch(['a'], [], timeout: [1]) },
      'validate_batch timeout 5.5' => -> { Zerobounce.validate_batch(['a'], [], timeout: 15.5) },
      'validate_file_check(nil)' => -> { Zerobounce.validate_file_check(nil) },
      'validate_file_delete(nil)' => -> { Zerobounce.validate_file_delete(nil) },
      'validate_file_get(nil)' => -> { Zerobounce.validate_file_get(nil) },
      'scoring_file_check(nil)' => -> { Zerobounce.scoring_file_check(nil) },
      'scoring_file_delete(blank)' => -> { Zerobounce.scoring_file_delete(' ') },
      'scoring_file_get(nil)' => -> { Zerobounce.scoring_file_get(nil) },
      'validate_file_send column "1"' => -> { Zerobounce.validate_file_send('x', email_address_column: '1') },
      'validate_file_send column nil' => -> { Zerobounce.validate_file_send('x', email_address_column: nil) },
      'scoring_file_send column 0' => -> { Zerobounce.scoring_file_send('x', email_address_column: 0) },
      'validate_file_send_stream nil io' => -> { Zerobounce.validate_file_send_stream(nil, nil) },
      'validate_file_send_stream no name' => -> { Zerobounce.validate_file_send_stream('a@b.c', '') },
      'scoring_file_send_stream nil' => -> { Zerobounce.scoring_file_send_stream(nil, 'f.csv') },
      'scoring_file_send_stream empty' => -> { Zerobounce.scoring_file_send_stream('', 'f.csv') },
      'guessformat domain 5' => -> { Zerobounce.guessformat(5) },
      'guessformat first 5' => -> { Zerobounce.guessformat('a.com', first_name: 5) },
      'guessformat middle 5' => -> { Zerobounce.guessformat('a.com', middle_name: 5) },
      'find_email domain 5' => -> { Zerobounce.find_email('J', domain: 5) },
      'find_email company []' => -> { Zerobounce.find_email('J', company_name: []) },
      'find_email first 5' => -> { Zerobounce.find_email(5, domain: 'a.com') },
      'find_email middle 5' => -> { Zerobounce.find_email('J', domain: 'a.com', middle_name: 5) },
      'find_domain domain 5' => -> { Zerobounce.find_domain(domain: 5) },
      'find_domain none' => -> { Zerobounce.find_domain },
      'find_domain both' => -> { Zerobounce.find_domain(domain: 'a.com', company_name: 'A') },
      'api_usage 5' => -> { Zerobounce.api_usage(5, 6) },
      'api_usage nil' => -> { Zerobounce.api_usage(nil, nil) }
    }.compact.each do |name, call|
      it "refuses #{name} with ArgumentError before sending" do
        answer('{}')
        expect { instance_exec(&call) }.to raise_error(ArgumentError)
        no_request
      end
    end

    it 'gives the SDK message for a bad timeout' do
      expect { Zerobounce.validate('a@b.c', timeout: 'abc') }
        .to raise_error(ArgumentError, 'Invalid parameter: timeout must be a whole number of seconds')
      expect { Zerobounce.validate('a@b.c', timeout: 5.5) }
        .to raise_error(ArgumentError, 'Invalid parameter: timeout must be a whole number of seconds')
      expect { Zerobounce.validate('a@b.c', timeout: 2) }
        .to raise_error(ArgumentError, 'Invalid parameter: timeout (must be between 3 and 60 seconds)')
    end

    it 'gives validate_batch real messages' do
      expect { Zerobounce.validate_batch('a') }
        .to raise_error(ArgumentError, 'Invalid parameter: emails must be an Array of Strings')
      expect { Zerobounce.validate_batch(['a'], nil, timeout: 5) }
        .to raise_error(ArgumentError, 'Invalid parameter: timeout (must be between 10 and 120 seconds)')
    end

    it 'accepts a nil ip_addresses and omits the IP of a row without one' do
      stub = stub_request(:post, /validatebatch/).with do |req|
        JSON.parse(req.body)['email_batch'] == [{ 'email_address' => 'a@b.c' }]
      end.to_return(status: 200, body: '{"email_batch":[],"errors":[]}', headers: json)
      Zerobounce.validate_batch(['a@b.c'], nil)
      expect(stub).to have_been_requested
    end

    it 'sends has_header_row on validate_file_send only when given' do
      stub = stub_request(:post, %r{/sendfile}).with { |req| !req.body.include?('has_header_row') }
                                               .to_return(status: 200, body: '{"success":true}', headers: json)
      Zerobounce.validate_file_send(File.join('spec', 'fixtures', 'priority3_finder.csv'))
      expect(stub).to have_been_requested
    end
  end
end
# rubocop:enable Metrics/BlockLength, Lint/ConstantDefinitionInBlock
