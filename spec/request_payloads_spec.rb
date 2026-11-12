# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength, Metrics/ModuleLength, Naming/VariableNumber
# The exact request every public request method builds: verb, host, path,
# query and body (JSON, form or multipart fields). A wrong field name - a
# mutant that sends `old_address` for `old_from_address` - fails here. The
# tables cover every public request method; a new one fails the completeness
# checks until it is added.
module RequestPayloads
  KEY = 'payload-key'
  F = 'spec/fixtures/priority3_finder.csv'
  D = 'https://example.com/d'
  NOT_REQUESTS = %i[configuration config configure configuration= with_api_key
                    get_file_json_indicates_error? zb_request].freeze

  # name (the method, then an optional variant) => [call, the one request it sends]
  CORE = {
    'validate' => [
      lambda {
        Zerobounce.validate(
          'a@example.com', '1.2.3.4',
          timeout: 10, activity_data: true, verify_plus: false, domain_info: true, greylist_processing: true,
          callback_url: D
        )
      },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/validate',
        query: {
          'activity_data' => 'true',
          'api_key' => 'payload-key',
          'callback_url' => 'https://example.com/d',
          'domain_info' => 'true',
          'email' => 'a@example.com',
          'greylist_processing' => 'true',
          'ip_address' => '1.2.3.4',
          'timeout' => '10',
          'verify_plus' => 'false'
        },
        body: nil
      }
    ],
    'validate use_post' => [
      -> { Zerobounce.validate('a@example.com', '1.2.3.4', timeout: 10, activity_data: true, use_post: true) },
      {
        verb: 'POST',
        url: 'api.zerobounce.net/v2/validate',
        query: {},
        body: {
          'email' => 'a@example.com',
          'ip_address' => '1.2.3.4',
          'timeout' => '10',
          'activity_data' => 'true',
          'api_key' => 'payload-key'
        }
      }
    ],
    'credits' => [
      -> { Zerobounce.credits },
      { verb: 'GET', url: 'api.zerobounce.net/v2/getcredits', query: { 'api_key' => 'payload-key' }, body: nil }
    ],
    'api_usage' => [
      -> { Zerobounce.api_usage(Date.new(2024, 1, 1), Date.new(2024, 1, 2)) },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/getapiusage',
        query: { 'api_key' => 'payload-key', 'end_date' => '2024-01-02', 'start_date' => '2024-01-01' },
        body: nil
      }
    ],
    'activity' => [
      -> { Zerobounce.activity('a@example.com') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/activity',
        query: { 'api_key' => 'payload-key', 'email' => 'a@example.com' },
        body: nil
      }
    ],
    'score_email' => [
      -> { Zerobounce.score_email('a@example.com') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/scoring',
        query: { 'api_key' => 'payload-key', 'email' => 'a@example.com' },
        body: nil
      }
    ],
    'score_email use_post' => [
      -> { Zerobounce.score_email('a@example.com', use_post: true) },
      {
        verb: 'POST',
        url: 'api.zerobounce.net/v2/scoring',
        query: {},
        body: { 'email' => 'a@example.com', 'api_key' => 'payload-key' }
      }
    ],
    'validate_batch' => [
      lambda {
        Zerobounce.validate_batch(
          ['a@example.com', 'b@example.com'], ['1.2.3.4', nil],
          timeout: 30, activity_data: true, verify_plus: true
        )
      },
      {
        verb: 'POST',
        url: 'api.zerobounce.net/v2/validatebatch',
        query: {},
        body: {
          'email_batch' => [
            { 'email_address' => 'a@example.com', 'ip_address' => '1.2.3.4' },
            { 'email_address' => 'b@example.com', 'ip_address' => nil }
          ],
          'timeout' => '30',
          'activity_data' => true,
          'verify_plus' => true,
          'api_key' => 'payload-key'
        }
      }
    ],
    'validate_file_send' => [
      lambda {
        Zerobounce.validate_file_send(
          F,
          email_address_column: 1, first_name_column: 2, last_name_column: 3, gender_column: 4, ip_address_column: 5,
          has_header_row: false, remove_duplicate: false, return_url: D, allow_phase_2: true
        )
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/sendfile',
        query: {},
        body: {
          'email_address_column' => '1',
          'has_header_row' => 'false',
          'first_name_column' => '2',
          'last_name_column' => '3',
          'gender_column' => '4',
          'ip_address_column' => '5',
          'remove_duplicate' => 'false',
          'return_url' => 'https://example.com/d',
          'allow_phase_2' => 'true',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'validate_file_send unset' => [
      -> { Zerobounce.validate_file_send(F) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/sendfile',
        query: {},
        body: {
          'email_address_column' => '1',
          'has_header_row' => 'true',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'validate_file_send_stream' => [
      lambda {
        Zerobounce.validate_file_send_stream(
          StringIO.new("e\n"), 'f.csv',
          email_address_column: 2, remove_duplicate: true
        )
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/sendfile',
        query: {},
        body: {
          'email_address_column' => '2',
          'has_header_row' => 'true',
          'remove_duplicate' => 'true',
          'api_key' => 'payload-key',
          'file' => '<file f.csv>'
        }
      }
    ],
    'validate_file_check' => [
      -> { Zerobounce.validate_file_check('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/filestatus',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'validate_file_get' => [
      lambda {
        Zerobounce.validate_file_get(
          'f1', Zerobounce::GetFileOptions.new(download_type: 'phase_1', activity_data: true)
        )
      },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/getfile',
        query: { 'activity_data' => 'true', 'api_key' => 'payload-key', 'download_type' => 'phase_1',
                 'file_id' => 'f1' },
        body: nil
      }
    ],
    'validate_file_delete' => [
      -> { Zerobounce.validate_file_delete('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/deletefile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'scoring_file_send' => [
      lambda {
        Zerobounce.scoring_file_send(
          F,
          email_address_column: 2, has_header_row: false, remove_duplicate: false, return_url: D
        )
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/scoring/sendfile',
        query: {},
        body: {
          'email_address_column' => '2',
          'has_header_row' => 'false',
          'remove_duplicate' => 'false',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'scoring_file_send_stream' => [
      -> { Zerobounce.scoring_file_send_stream(StringIO.new("e\n"), 'f.csv') },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/scoring/sendfile',
        query: {},
        body: {
          'email_address_column' => '1',
          'has_header_row' => 'true',
          'api_key' => 'payload-key',
          'file' => '<file f.csv>'
        }
      }
    ],
    'scoring_file_get' => [
      -> { Zerobounce.scoring_file_get('f1', Zerobounce::GetFileOptions.new(download_type: 'combined')) },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/scoring/getfile',
        query: { 'api_key' => 'payload-key', 'download_type' => 'combined', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'scoring_file_check' => [
      -> { Zerobounce.scoring_file_check('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/scoring/filestatus',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'scoring_file_delete' => [
      -> { Zerobounce.scoring_file_delete('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/scoring/deletefile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'guessformat' => [
      -> { Zerobounce.guessformat('example.com', first_name: 'Ann', middle_name: 'B', last_name: 'Lee') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/guessformat',
        query: {
          'api_key' => 'payload-key',
          'domain' => 'example.com',
          'first_name' => 'Ann',
          'last_name' => 'Lee',
          'middle_name' => 'B'
        },
        body: nil
      }
    ],
    'find_email' => [
      -> { Zerobounce.find_email('Ann', domain: 'example.com', middle_name: 'B', last_name: 'Lee') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/guessformat',
        query: {
          'api_key' => 'payload-key',
          'domain' => 'example.com',
          'first_name' => 'Ann',
          'last_name' => 'Lee',
          'middle_name' => 'B'
        },
        body: nil
      }
    ],
    'find_email company_name' => [
      -> { Zerobounce.find_email('Ann', company_name: 'Acme') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/guessformat',
        query: { 'api_key' => 'payload-key', 'company_name' => 'Acme', 'first_name' => 'Ann' },
        body: nil
      }
    ],
    'find_domain' => [
      -> { Zerobounce.find_domain(domain: 'example.com') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/guessformat',
        query: { 'api_key' => 'payload-key', 'domain' => 'example.com' },
        body: nil
      }
    ],
    'find_domain company_name' => [
      -> { Zerobounce.find_domain(company_name: 'Acme') },
      {
        verb: 'GET',
        url: 'api.zerobounce.net/v2/guessformat',
        query: { 'api_key' => 'payload-key', 'company_name' => 'Acme' },
        body: nil
      }
    ],
    'send_email_finder_file' => [
      lambda {
        Zerobounce.send_email_finder_file(
          F,
          domain_column: 1, first_name_column: 2, last_name_column: 3, middle_name_column: 4, has_header_row: false
        )
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/email-finder/sendfile',
        query: {},
        body: {
          'domain_column' => '1',
          'has_header_row' => 'false',
          'first_name_column' => '2',
          'last_name_column' => '3',
          'middle_name_column' => '4',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'send_email_finder_file full_name' => [
      -> { Zerobounce.send_email_finder_file(F, domain_column: 1, full_name_column: 2) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/email-finder/sendfile',
        query: {},
        body: {
          'domain_column' => '1',
          'full_name_column' => '2',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'email_finder_file_status' => [
      -> { Zerobounce.email_finder_file_status('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/email-finder/filestatus',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'email_finder_file_get' => [
      -> { Zerobounce.email_finder_file_get('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/email-finder/getfile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'email_finder_file_delete' => [
      -> { Zerobounce.email_finder_file_delete('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/email-finder/deletefile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'send_domain_search_file' => [
      -> { Zerobounce.send_domain_search_file(F, domain_column: 1, has_header_row: false) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/domain-search/sendfile',
        query: {},
        body: {
          'domain_column' => '1',
          'has_header_row' => 'false',
          'api_key' => 'payload-key',
          'file' => '<file priority3_finder.csv>'
        }
      }
    ],
    'domain_search_file_status' => [
      -> { Zerobounce.domain_search_file_status('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/domain-search/filestatus',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'domain_search_file_get' => [
      -> { Zerobounce.domain_search_file_get('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/domain-search/getfile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'domain_search_file_delete' => [
      -> { Zerobounce.domain_search_file_delete('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/domain-search/deletefile',
        query: { 'api_key' => 'payload-key', 'file_id' => 'f1' },
        body: nil
      }
    ],
    'send_list_evaluator_file' => [
      -> { Zerobounce.send_list_evaluator_file(F, email_address_column: 3) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/listevaluator/',
        query: {},
        body: { 'email_address_column' => '3', 'api_key' => 'payload-key', 'file' => '<file priority3_finder.csv>' }
      }
    ],
    'get_list_evaluator_result' => [
      -> { Zerobounce.get_list_evaluator_result('f1') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/v2/listevaluator/f1/',
        query: { 'api_key' => 'payload-key' },
        body: nil
      }
    ],
    'send_evaluated_file' => [
      -> { Zerobounce.send_evaluated_file('f1') },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/v2/send-evaluated-file/',
        query: {},
        body: { 'file_id' => 'f1', 'api_key' => 'payload-key' }
      }
    ],
    'add_filter' => [
      -> { Zerobounce.add_filter(rule: 'allow', target: 'domain', value: 'example.com') },
      {
        verb: 'POST',
        url: 'api.zerobounce.net/v2/filters/add',
        query: {},
        body: { 'rule' => 'allow', 'target' => 'domain', 'value' => 'example.com', 'api_key' => 'payload-key' }
      }
    ],
    'list_filters' => [
      -> { Zerobounce.list_filters },
      { verb: 'GET', url: 'api.zerobounce.net/v2/filters/list', query: { 'api_key' => 'payload-key' }, body: nil }
    ],
    'list_filters use_post' => [
      -> { Zerobounce.list_filters(use_post: true) },
      { verb: 'POST', url: 'api.zerobounce.net/v2/filters/list', query: {}, body: { 'api_key' => 'payload-key' } }
    ],
    'delete_filter' => [
      -> { Zerobounce.delete_filter(rule: 'block', target: 'email', value: 'a@example.com') },
      {
        verb: 'POST',
        url: 'api.zerobounce.net/v2/filters/delete',
        query: {},
        body: { 'rule' => 'block', 'target' => 'email', 'value' => 'a@example.com', 'api_key' => 'payload-key' }
      }
    ],
    'list_s3_files' => [
      -> { Zerobounce.list_s3_files(bucket: 'bkt', search: 'abc') },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/listS3files',
        query: { 'api_key' => 'payload-key', 'bucket' => 'bkt', 'search' => 'abc' },
        body: nil
      }
    ],
    'validate_s3_file' => [
      lambda {
        Zerobounce.validate_s3_file(file_name: 'f.csv', has_header_row: true, return_url: D, remove_duplicates: false)
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/validateS3file',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'remove_duplicates' => 'false',
          'api_key' => 'payload-key'
        }
      }
    ],
    'score_s3_file' => [
      -> { Zerobounce.score_s3_file(file_name: 'f.csv', return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/scoreS3file',
        query: {},
        body: {
          'has_header_row' => 'false',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'export_s3_file' => [
      -> { Zerobounce.export_s3_file(file_id: 'f1', export_bucket: 'out') },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/exportS3file',
        query: {},
        body: { 'file_id' => 'f1', 'export_bucket' => 'out', 'api_key' => 'payload-key' }
      }
    ],
    'email_finder_s3_file' => [
      -> { Zerobounce.email_finder_s3_file('f.csv', true, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/emailFinderS3file',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'domain_search_s3_file' => [
      -> { Zerobounce.domain_search_s3_file('f.csv', false, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/domainSearchS3file',
        query: {},
        body: {
          'has_header_row' => 'false',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'validate_sftp_file' => [
      -> { Zerobounce.validate_sftp_file('f.csv', true, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/validateSFTPfile',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'score_sftp_file' => [
      -> { Zerobounce.score_sftp_file('f.csv', true, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/scoreSFTPfile',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'email_finder_sftp_file' => [
      -> { Zerobounce.email_finder_sftp_file('f.csv', true, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/emailFinderSFTPfile',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'domain_search_sftp_file' => [
      -> { Zerobounce.domain_search_sftp_file('f.csv', true, return_url: D) },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/domainSearchSFTPfile',
        query: {},
        body: {
          'has_header_row' => 'true',
          'file_name' => 'f.csv',
          'return_url' => 'https://example.com/d',
          'api_key' => 'payload-key'
        }
      }
    ],
    'export_sftp_file' => [
      -> { Zerobounce.export_sftp_file(file_id: 'f1', export_path: '/out') },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/exportSFTPfile',
        query: {},
        body: { 'file_id' => 'f1', 'export_path' => '/out', 'api_key' => 'payload-key' }
      }
    ],
    'inbox_placement_providers' => [
      -> { Zerobounce.inbox_placement_providers },
      { verb: 'GET', url: 'bulkapi.zerobounce.net/api/ipt/providers', query: {}, body: nil }
    ],
    'inbox_placement_test_types' => [
      -> { Zerobounce.inbox_placement_test_types },
      { verb: 'GET', url: 'bulkapi.zerobounce.net/api/ipt/test-types', query: {}, body: nil }
    ],
    'create_inbox_placement_test' => [
      lambda {
        Zerobounce.create_inbox_placement_test(
          'Test',
          test_type: 1, sender_email: 's@example.com', provider_ids: [1, 2], seed_ids: [3], providers: ['gmail'],
          webhook_url: 'https://example.com/h'
        )
      },
      {
        verb: 'POST',
        url: 'bulkapi.zerobounce.net/api/ipt/test',
        query: {},
        body: {
          'name' => 'Test',
          'testType' => 1,
          'senderEmail' => 's@example.com',
          'providerIds' => [1, 2],
          'seedIds' => [3],
          'providers' => ['gmail'],
          'webhookUrl' => 'https://example.com/h'
        }
      }
    ],
    'inbox_placement_test' => [
      -> { Zerobounce.inbox_placement_test('7') },
      { verb: 'GET', url: 'bulkapi.zerobounce.net/api/ipt/test/7', query: {}, body: nil }
    ],
    'list_inbox_placement_tests' => [
      lambda {
        Zerobounce.list_inbox_placement_tests(
          status: 'done', created_after: '2026-01-01', created_before: '2026-02-01', page: 2, page_size: 10
        )
      },
      {
        verb: 'GET',
        url: 'bulkapi.zerobounce.net/api/ipt/tests',
        query: {
          'createdAfter' => '2026-01-01',
          'createdBefore' => '2026-02-01',
          'page' => '2',
          'page_size' => '10',
          'status' => 'done'
        },
        body: nil
      }
    ],
    'delete_inbox_placement_test' => [
      -> { Zerobounce.delete_inbox_placement_test('7') },
      { verb: 'DELETE', url: 'bulkapi.zerobounce.net/api/ipt/test/7', query: {}, body: nil }
    ],
    'inbox_placement_webhook' => [
      -> { Zerobounce.inbox_placement_webhook },
      { verb: 'GET', url: 'bulkapi.zerobounce.net/api/ipt/webhook', query: {}, body: nil }
    ],
    'set_inbox_placement_webhook' => [
      -> { Zerobounce.set_inbox_placement_webhook('https://example.com/hook') },
      {
        verb: 'PUT',
        url: 'bulkapi.zerobounce.net/api/ipt/webhook',
        query: {},
        body: { 'webhookUrl' => 'https://example.com/hook' }
      }
    ]
  }.freeze

  # Called on a Warmup client, whose key goes in the API-Key header.
  WARMUP = {
    'list_sending_accounts' => [
      ->(w) { w.list_sending_accounts },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/sending-accounts', query: {}, body: nil }
    ],
    'get_sending_account' => [
      ->(w) { w.get_sending_account('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/sending-account',
        query: { 'from_address' => 'a@b.com' },
        body: nil
      }
    ],
    'add_sending_account' => [
      ->(w) { w.add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 0) },
      {
        verb: 'POST',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/sending-accounts',
        query: {},
        body: { 'from_address' => 'a@b.com', 'onboarding_model' => 'self_managed', 'engagement_rule_id' => 0 }
      }
    ],
    'update_sending_account' => [
      ->(w) { w.update_sending_account('a@b.com', 1, 4, true) },
      {
        verb: 'PUT',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/sending-accounts',
        query: {},
        body: {
          'team_id' => 1,
          'from_address' => 'a@b.com',
          'engagement_rule_id' => 1,
          'status_id' => 4,
          'auto_enable' => true
        }
      }
    ],
    'delete_sending_account' => [
      ->(w) { w.delete_sending_account('a@b.com') },
      {
        verb: 'DELETE',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/sending-accounts',
        query: { 'from_address' => 'a@b.com' },
        body: nil
      }
    ],
    'change_from_address' => [
      ->(w) { w.change_from_address('a@b.com', 'c@d.com') },
      {
        verb: 'PUT',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/smtp-credentials',
        query: {},
        body: { 'team_id' => 1, 'old_from_address' => 'a@b.com', 'new_from_address' => 'c@d.com' }
      }
    ],
    'list_from_addresses' => [
      ->(w) { w.list_from_addresses(search_from: 'a', offset: 5, limit: 10) },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/from-addresses',
        query: { 'limit' => '10', 'offset' => '5', 'search_from' => 'a' },
        body: nil
      }
    ],
    'engagement_rules' => [
      ->(w) { w.engagement_rules },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/engagement-rules', query: {}, body: nil }
    ],
    'set_engagement_rule' => [
      ->(w) { w.set_engagement_rule('a@b.com', 2) },
      {
        verb: 'PUT',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/engagement-rule',
        query: { 'c_from' => 'a@b.com' },
        body: { 'rule_id' => 2 }
      }
    ],
    'custom_engagement' => [
      ->(w) { w.custom_engagement('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/custom-engagement/a@b.com',
        query: {},
        body: nil
      }
    ],
    'create_custom_engagement' => [
      ->(w) { w.create_custom_engagement('a@b.com', 10, 20, 5) },
      {
        verb: 'POST',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/custom-engagement',
        query: {},
        body: { 'c_from' => 'a@b.com', 'reply_pct' => 10, 'important_pct' => 20, 'click_pct' => 5 }
      }
    ],
    'update_custom_engagement' => [
      ->(w) { w.update_custom_engagement('a@b.com', 11, 21, 6) },
      {
        verb: 'PUT',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/custom-engagement',
        query: {},
        body: { 'c_from' => 'a@b.com', 'reply_pct' => 11, 'important_pct' => 21, 'click_pct' => 6 }
      }
    ],
    'delete_custom_engagement' => [
      ->(w) { w.delete_custom_engagement('a@b.com', 1) },
      {
        verb: 'DELETE',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/custom-engagement',
        query: {},
        body: { 'c_from' => 'a@b.com', 'engagement_rule_id' => 1 }
      }
    ],
    'seeds' => [
      ->(w) { w.seeds },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/seeds', query: {}, body: nil }
    ],
    'download_seeds' => [
      ->(w) { w.download_seeds },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/seeds/download', query: {}, body: nil }
    ],
    'seed_count' => [
      ->(w) { w.seed_count },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/seed-count', query: {}, body: nil }
    ],
    'progress_today' => [
      ->(w) { w.progress_today },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/progress-today', query: {}, body: nil }
    ],
    'sent_today' => [
      ->(w) { w.sent_today },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/sent-today', query: {}, body: nil }
    ],
    'emails_per_day' => [
      ->(w) { w.emails_per_day },
      { verb: 'GET', url: 'warmup-api.zerobounce.net/api/v1/warmup/emails-per-day', query: {}, body: nil }
    ],
    'statistics' => [
      ->(w) { w.statistics('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/statistics',
        query: { 'from_address' => 'a@b.com' },
        body: nil
      }
    ],
    'statistics_per_day' => [
      ->(w) { w.statistics_per_day('a@b.com', '2026-09-01', '2026-09-14') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/statistics-per-day',
        query: { 'end_date' => '2026-09-14', 'from_address' => 'a@b.com', 'start_date' => '2026-09-01' },
        body: nil
      }
    ],
    'statistics_detailed' => [
      ->(w) { w.statistics_detailed('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/statistics-detailed',
        query: { 'c_from' => 'a@b.com' },
        body: nil
      }
    ],
    'download_statistics' => [
      ->(w) { w.download_statistics('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/statistics/download',
        query: { 'c_from' => 'a@b.com' },
        body: nil
      }
    ],
    'from_address_statistics' => [
      ->(w) { w.from_address_statistics('a@b.com') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/from-address-statistics',
        query: { 'from_address' => 'a@b.com' },
        body: nil
      }
    ],
    'check_domain_dmarc' => [
      ->(w) { w.check_domain_dmarc('a@b.com', dkim_selector: 'sel') },
      {
        verb: 'GET',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/check-domain-dmarc',
        query: { 'dkim_selector' => 'sel', 'from_address' => 'a@b.com' },
        body: nil
      }
    ],
    'test_smtp_configuration' => [
      ->(w) { w.test_smtp_configuration('a@b.com', 'user', 'pass', 'smtp.example.com', 587) },
      {
        verb: 'POST',
        url: 'warmup-api.zerobounce.net/api/v1/warmup/test-smtp-configuration',
        query: {},
        body: {
          'from_address' => 'a@b.com',
          'username' => 'user',
          'password' => 'pass',
          'server' => 'smtp.example.com',
          'port' => 587
        }
      }
    ]
  }.freeze

  module_function

  def multipart(body, content_type)
    boundary = content_type[/boundary=([^;]+)/, 1]
    body.split("--#{boundary}").each_with_object({}) do |part, fields|
      name = part[/name="([^"]+)"/, 1]
      next if name.nil?

      file = part[/filename="([^"]*)"/, 1]
      fields[name] = file ? "<file #{file}>" : part.split("\r\n\r\n", 2)[1].to_s.chomp("\r\n")
    end
  end

  def body_of(request)
    type = request.headers['Content-Type'].to_s
    body = request.body.to_s
    return nil if body.empty?
    return JSON.parse(body) if type.include?('json')
    return multipart(body, type) if type.include?('multipart')

    URI.decode_www_form(body).to_h
  end

  def shape(request)
    uri = request.uri
    {
      verb: request.method.to_s.upcase,
      url: "#{uri.host}#{uri.path}",
      query: URI.decode_www_form(uri.query.to_s).to_h,
      body: body_of(request)
    }
  end
end

describe 'request payloads' do
  def requests
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys
  end

  def capture
    WebMock.reset!
    stub_request(:any, /.*/).to_return(status: 200, body: '{"success":true}',
                                       headers: { 'Content-Type' => 'application/json' })
    begin
      yield
    rescue StandardError
      nil # The answer does not matter here, only what was sent.
    end
    requests.map { |request| RequestPayloads.shape(request) }
  end

  before { Zerobounce.configure { |c| c.apikey = RequestPayloads::KEY } }

  it 'covers every public request method of the client' do
    covered = RequestPayloads::CORE.keys.map { |name| name.split.first.to_sym }
    expect(Zerobounce.singleton_methods - RequestPayloads::NOT_REQUESTS - covered).to eq([])
  end

  it 'covers every public method of the Warmup client' do
    expect(Zerobounce::Warmup.public_instance_methods(false) - %i[inspect] -
           RequestPayloads::WARMUP.keys.map(&:to_sym)).to eq([])
  end

  RequestPayloads::CORE.each do |name, (call, expected)|
    it "sends exactly the documented request for #{name}" do
      expect(capture { call.call }).to eq([expected])
    end
  end

  RequestPayloads::WARMUP.each do |name, (call, expected)|
    it "sends exactly the documented request for Warmup##{name}" do
      expect(capture { call.call(Zerobounce::Warmup.new('warmup-key')) }).to eq([expected])
    end
  end
end
# rubocop:enable Metrics/BlockLength, Metrics/ModuleLength, Naming/VariableNumber
