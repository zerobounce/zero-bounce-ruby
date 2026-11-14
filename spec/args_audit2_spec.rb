# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# Audit 2, arguments: every bad argument is refused before a request is sent.
# rubocop:disable Metrics/BlockLength
describe 'Argument checks (audit 2)' do
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:csv) { File.join(__dir__, 'fixtures', 'priority3_finder.csv') }
  let(:warmup) { Zerobounce::Warmup.new('warmup-key') }

  before do
    Zerobounce.configure { |c| c.apikey = 'args-spec-key' }
    stub_request(:any, /.*/).to_return(status: 200, body: '{"ok":true}', headers: json)
  end

  let(:bad_ids) { [nil, '  ', 5] }

  def refused(error = ArgumentError, match = nil, &block)
    expect(&block).to raise_error(error, match)
    expect(WebMock).not_to have_requested(:any, /.*/)
  end

  it 'refuses a nil or blank file id on the finder and domain search file calls' do
    %i[email_finder_file_status email_finder_file_get email_finder_file_delete
       domain_search_file_status domain_search_file_get domain_search_file_delete].each do |method|
      bad_ids.each { |bad| refused(ArgumentError, /file_id/) { Zerobounce.public_send(method, bad) } }
    end
  end

  it 'checks every column with the shared integer helper' do
    [[1], {}, 1.5, '2x', '3abc', 0, -3].each do |bad|
      refused(ArgumentError, /domain_column/) do
        Zerobounce.send_email_finder_file(csv, domain_column: bad, first_name_column: 2)
      end
      refused(ArgumentError, /domain_column/) { Zerobounce.send_domain_search_file(csv, domain_column: bad) }
      refused(ArgumentError, /email_address_column/) do
        Zerobounce.send_list_evaluator_file(csv, email_address_column: bad)
      end
    end
    %i[first_name_column last_name_column middle_name_column full_name_column].each do |name|
      refused(ArgumentError, /#{name}/) do
        Zerobounce.send_email_finder_file(csv, domain_column: 1, first_name_column: 1, name => 'abc')
      end
    end
    refused(ArgumentError, /first_name_column/) do
      Zerobounce.send_email_finder_file(csv, domain_column: 1, first_name_column: 'abc')
    end
  end

  it 'reads list_filters use_post strictly' do
    refused(ArgumentError, /use_post/) { Zerobounce.list_filters(use_post: 'junk') }
    refused(ArgumentError, /use_post/) { Zerobounce.list_filters(use_post: 1.5) }
    stub_request(:get, %r{/filters/list}).to_return(status: 200, body: '[]', headers: json)
    Zerobounce.list_filters(use_post: false)
    expect(WebMock).to have_requested(:get, %r{/filters/list})
  end

  it 'requires documented, non-blank filter values' do
    %i[add_filter delete_filter].each do |method|
      refused(ArgumentError, /Empty parameter/) { Zerobounce.public_send(method, rule: nil, target: nil, value: nil) }
      refused(ArgumentError, /Empty parameter/) do
        Zerobounce.public_send(method, rule: 'allow', target: 'domain', value: ' ')
      end
      refused(ArgumentError, /Empty parameter/) do
        Zerobounce.public_send(method, rule: 'allow', target: 5, value: 'a.com')
      end
      refused(ArgumentError, /rule \(must be allow or block\)/) do
        Zerobounce.public_send(method, rule: 'junk', target: 'domain', value: 'a.com')
      end
      refused(ArgumentError, /target \(must be email, domain, mx or tld\)/) do
        Zerobounce.public_send(method, rule: 'allow', target: 'junk', value: 'a.com')
      end
    end
  end

  it 'validates list_inbox_placement_tests options' do
    { page_size: [[1], '5x', 2.7, 0, 101], page: [-1, 0, 'x', 1.5], created_after: %w[junk 2026-02-30],
      created_before: [5], status: %w[done junk] }.each do |key, bads|
      bads.each { |bad| refused(ArgumentError, /#{key}/) { Zerobounce.list_inbox_placement_tests(key => bad) } }
    end
    refused(ArgumentError, /Unknown option: pagesize/) { Zerobounce.list_inbox_placement_tests(pagesize: 5) }
    Zerobounce.list_inbox_placement_tests(created_after: Date.new(2026, 1, 2))
    expect(WebMock).to have_requested(:get, %r{/api/ipt/tests})
      .with(query: hash_including('createdAfter' => '2026-01-02'))
  end

  it 'accepts test_type as an Integer or a digits-only String and sends a number' do
    [2, '2'].each do |given|
      WebMock.reset_executed_requests!
      Zerobounce.create_inbox_placement_test('n', test_type: given)
      expect(WebMock).to(have_requested(:post, /ipt/).with { |req| JSON.parse(req.body)['testType'] == 2 })
    end
  end

  it 'type-checks create_inbox_placement_test' do
    refused(ArgumentError, /name/) { Zerobounce.create_inbox_placement_test(5) }
    ['2x', ' 2', '', 2.0, nil, true].each do |bad|
      refused(ArgumentError, /test_type/) { Zerobounce.create_inbox_placement_test('n', test_type: bad) }
    end
    refused(ArgumentError, /Unknown option: sendr_email/) do
      Zerobounce.create_inbox_placement_test('n', sendr_email: 'x')
    end
    refused(ArgumentError, /sender_email/) { Zerobounce.create_inbox_placement_test('n', sender_email: 5) }
    refused(ArgumentError, /provider_ids must be an array/) do
      Zerobounce.create_inbox_placement_test('n', provider_ids: 1)
    end
    refused(ArgumentError, /webhook_url/) { Zerobounce.create_inbox_placement_test('n', webhook_url: 'http://x.io') }
  end

  it 'requires an https URL string for the webhook' do
    [5, 'not a url', 'http://example.com/h', 'https://', ['https://a.io']].each do |bad|
      refused(ArgumentError, /webhook_url/) { Zerobounce.set_inbox_placement_webhook(bad) }
    end
  end

  it 'validates the S3 and SFTP jobs' do
    refused(ArgumentError, /Unknown option: remove_duplicate\b/) do
      Zerobounce.validate_s3_file(file_name: 'a', return_url: 'https://x.io', remove_duplicate: true)
    end
    refused(ArgumentError, /return_url/) { Zerobounce.validate_s3_file(file_name: 'a', return_url: 'notaurl') }
    refused(ArgumentError, /file_name/) { Zerobounce.validate_s3_file(file_name: 5, return_url: 'https://x.io') }
    refused(ArgumentError, /file_id/) { Zerobounce.export_s3_file(file_id: []) }
    refused(ArgumentError, /file_id/) { Zerobounce.export_sftp_file(file_id: []) }
    refused(ArgumentError, /export_bucket/) { Zerobounce.export_s3_file(file_id: 'f', export_bucket: 5) }
    refused(ArgumentError, /bucket/) { Zerobounce.list_s3_files(bucket: 5) }
  end

  it 'treats an empty body as success only for the IPT DELETE' do
    [204, 200].each do |status|
      stub_request(:any, /.*/).to_return(status: status, body: '')
      expect { Zerobounce.inbox_placement_providers }
        .to raise_error(Zerobounce::ApiResponseError, /Empty response from ZeroBounce \(HTTP #{status}\)/)
      expect { Zerobounce.set_inbox_placement_webhook('https://example.com/h') }
        .to raise_error(Zerobounce::ApiResponseError, /Empty response/)
      expect(Zerobounce.delete_inbox_placement_test('7')).to be_nil
    end
  end

  it 'checks warmup dates strictly and strings only' do
    ['2026-02-30', '2026-13-45'].each do |bad|
      refused(ArgumentError, /YYYY-MM-DD/) { warmup.statistics_per_day('a@b.c', bad, '2026-03-01') }
    end
    [5, ['a']].each do |bad|
      refused(ArgumentError, /from_address/) { warmup.get_sending_account(bad) }
    end
  end

  it 'warns about an unknown add_sending_account option' do
    expect do
      warmup.add_sending_account('a@b.c', 'self_managed', engagement_rule_id: 1, ignore_conflit: true)
    end.to output(/ignore_conflit is not an option/).to_stderr
  end

  it 'gives api_usage SDK messages and refuses a reversed range' do
    refused(ArgumentError, /Invalid parameter: start_date must be a date/) { Zerobounce.api_usage('2026-02-30', 'x') }
    refused(ArgumentError, /Empty parameter: end_date/) { Zerobounce.api_usage(Date.new(2026, 1, 1), nil) }
    refused(ArgumentError, /start_date must not be after end_date/) do
      Zerobounce.api_usage(Date.new(2026, 2, 1), Date.new(2026, 1, 1))
    end
    Zerobounce.api_usage(Date.new(2026, 1, 1), Date.new(2026, 1, 1))
    expect(WebMock).to have_requested(:get, /getapiusage/)
  end
end
# rubocop:enable Metrics/BlockLength
