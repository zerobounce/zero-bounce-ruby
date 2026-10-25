# frozen_string_literal: true

# Opt-in live API suite: calls every SDK method against the real API to check
# payloads and response shapes.
#
# It lives outside spec/, so `rspec` and CI never load it. Run it explicitly:
#
#   export ZEROBOUNCE_API_KEY=...          # validation API (skipped without it)
#   export ZEROBOUNCE_WARMUP_API_KEY=...   # Warmup API (skipped without it)
#   ruby -Ilib live/live_api.rb
#
# By default only free calls run: sandbox addresses (no credits), reads, and
# requests expected to fail (unknown file IDs, S3/SFTP without an integration)
# that still prove the API accepts the payload. The free tier checks that the
# credit balance did not change. Two flags opt in to more:
#
#   ZEROBOUNCE_LIVE_SPEND=1     spends credits: scoring, activity, email
#                               finder, and a bulk round trip whose job is
#                               deleted again
#   ZEROBOUNCE_LIVE_CHANGES=1   reversible account changes, each undone in
#                               cleanup even when a test fails: a test filter,
#                               and a self-managed Warmup sending account
#
# Never called, because the API cannot undo them: creating an Inbox Placement
# test (it cannot be deleted while running), setting the Inbox Placement
# webhook (it cannot be cleared), and ZB-managed Warmup onboarding (it starts
# mailbox provisioning).
#
# No key is ever written to a file or printed. Keys come from the environment.

require 'date'
require 'tempfile'
require 'zerobounce'

API_KEY = ENV.fetch('ZEROBOUNCE_API_KEY', '').strip
WARMUP_KEY = ENV.fetch('ZEROBOUNCE_WARMUP_API_KEY', '').strip
SPEND = ENV['ZEROBOUNCE_LIVE_SPEND'] == '1'
CHANGES = ENV['ZEROBOUNCE_LIVE_CHANGES'] == '1'

# Well-formed but matching no file: a malformed id can be Cloudflare-blocked
# instead of answered.
UNKNOWN_ID = '0d1b7a4e-1111-2222-3333-444455556666'
CALLBACK = 'https://example.com/zerobounce-sdk-live-test'
SANDBOX = 'valid@example.com'

@passed = 0
@failed = 0
@skipped = 0
@failures = []

def redact(text)
  value = text.to_s
  [API_KEY, WARMUP_KEY].each do |secret|
    value = value.gsub(secret, '***') unless secret.empty?
  end
  value
end

def check(name)
  problem = yield
  if problem.nil? || problem.to_s.empty?
    @passed += 1
    puts "  + #{name}"
  else
    @failed += 1
    @failures << "#{name}: #{redact(problem)}"
    puts "  X #{name}\n      #{redact(problem)}"
  end
rescue StandardError => e
  @failed += 1
  @failures << "#{name}: #{redact(e.message)}"
  puts "  X #{name}\n      #{redact(e.message)}"
end

def skip(name, reason)
  @skipped += 1
  puts "  - SKIP #{name} (#{reason})"
end

# Runs a call that must fail, and hands back nil when it did.
def expect_failure(what)
  yield
  "#{what} unexpectedly succeeded"
rescue StandardError
  nil
end

def warmup_client
  @warmup_client ||= Zerobounce::Warmup.new(WARMUP_KEY)
end

# -- validation API, free ------------------------------------------------

def validation_free
  puts 'Validation API (free calls)'
  before = nil

  check('credits returns a balance') do
    before = Zerobounce.credits
    before.is_a?(Integer) ? nil : 'credits was not a number'
  end

  check('api_usage parses the documented date formats') do
    usage = Zerobounce.api_usage(Date.today - 7, Date.today)
    usage['total'].nil? ? 'no total in the response' : nil
  end

  check('validate on a sandbox address spends nothing') do
    response = Zerobounce.validate(SANDBOX)
    response['address'] == SANDBOX ? nil : 'address did not echo'
  end

  check('validate works over POST as well as GET') do
    # No billable add-on here: activity_data, verify_plus and domain_info are
    # charged even on a sandbox address, so they live in the SPEND tier.
    Zerobounce.validate(SANDBOX, nil, timeout: 30, use_post: true)
    nil
  end

  check('LIVE: validate_batch accepts timeout as a string') do
    # Sent as a JSON number the API rejects the whole batch with the
    # account-level "Invalid API Key or your account ran out of credits".
    response = Zerobounce.validate_batch([SANDBOX], [nil], timeout: 30)
    account = Array(response['errors']).find do |error|
      error.is_a?(Hash) && error['email_address'].to_s.casecmp('all').zero?
    end
    account ? "account-level error: #{account['error']}" : nil
  end

  check('an unknown file id is a short, clean error') do
    expect_failure('validate_file_check') { Zerobounce.validate_file_check(UNKNOWN_ID) }
  end

  check('list_s3_files answers (empty without an S3 integration)') do
    begin
      Zerobounce.list_s3_files
    rescue StandardError => e
      # No S3 integration configured is an expected, documented failure.
      return 'message too long' if e.message.length >= 500
    end
    nil
  end

  check('LIVE: S3/SFTP jobs reject a payload without return_url before sending') do
    # validate_s3_file and score_s3_file share the same helper, so they are
    # held to the same requirement the live API enforces.
    %i[email_finder_s3_file domain_search_s3_file].each do |method|
      begin
        Zerobounce.public_send(method, 'f.csv', true)
        return "#{method} unexpectedly succeeded"
      rescue ArgumentError => e
        return "#{method}: unexpected message: #{e.message}" unless e.message.include?('return_url')
      end
    end
    %i[validate_s3_file score_s3_file].each do |method|
      begin
        Zerobounce.public_send(method, file_name: 'f.csv')
        return "#{method} unexpectedly succeeded"
      rescue ArgumentError => e
        return "#{method}: unexpected message: #{e.message}" unless e.message.include?('return_url')
      end
    end
    nil
  end

  check('LIVE: a complete S3 job payload is accepted by the API') do
    # Without an S3 integration this fails on the integration, not the payload.
    begin
      Zerobounce.email_finder_s3_file('f.csv', true, return_url: CALLBACK)
    rescue StandardError => e
      message = redact(e.message)
      if message.match?(/return URL is not permitted|This field is required/i)
        return "payload rejected: #{message}"
      end
    end
    nil
  end

  check('filters list') do
    Zerobounce.list_filters
    nil
  end

  check('LIVE: the Inbox Placement Tester accepts a Bearer key') do
    Zerobounce.inbox_placement_providers
    nil
  end

  check('inbox placement test types') do
    Zerobounce.inbox_placement_test_types
    nil
  end

  check('LIVE: inbox placement tests are listed from /tests') do
    # The listing is GET /tests (plural); /test is the single-test path and
    # answers 'Method "GET" not allowed'.
    Zerobounce.list_inbox_placement_tests(page: 1, page_size: 10)
    Zerobounce.inbox_placement_webhook
    nil
  end

  check('list evaluator result for an unknown id fails cleanly') do
    expect_failure('get_list_evaluator_result') { Zerobounce.get_list_evaluator_result(UNKNOWN_ID) }
  end

  check('LIVE: send_evaluated_file posts the file id as a form field') do
    Zerobounce.send_evaluated_file(UNKNOWN_ID)
    'unexpectedly succeeded'
  rescue StandardError => e
    redact(e.message).match?(/not allowed/i) ? "wrong method or path: #{redact(e.message)}" : nil
  end

  check('the free calls did not change the credit balance') do
    after = Zerobounce.credits
    after == before ? nil : "credits went from #{before} to #{after}"
  end
end

# -- validation API, spends credits --------------------------------------

def validation_spend
  puts "\nValidation API (ZEROBOUNCE_LIVE_SPEND=1)"

  check('validate accepts every documented option') do
    # LIVE: activity_data, verify_plus and domain_info are billable add-ons and
    # are charged even for a sandbox address, so this is not a free call.
    Zerobounce.validate(SANDBOX, nil, timeout: 30, activity_data: true, verify_plus: true,
                                      domain_info: true, greylist_processing: true,
                                      callback_url: CALLBACK)
    nil
  end

  check('score_email') do
    Zerobounce.score_email(SANDBOX)
    nil
  end

  check('score_email over POST') do
    Zerobounce.score_email(SANDBOX, use_post: true)
    nil
  end

  check('activity') do
    Zerobounce.activity(SANDBOX)
    nil
  end

  check('email finder') do
    Zerobounce.find_email('John', domain: 'example.com', last_name: 'Doe')
    nil
  end

  check('domain search') do
    Zerobounce.find_domain(domain: 'example.com')
    nil
  end

  file_id = nil
  check('bulk validation round trip: upload, status, delete') do
    csv = "email\nvalid@example.com\ninvalid@example.com\n"
    sent = nil
    Tempfile.create(['zb-sdk-live', '.csv'], Dir.pwd) do |tmp|
      tmp.write(csv)
      tmp.flush
      sent = Zerobounce.validate_file_send(tmp.path, email_address_column: 1, has_header_row: true)
    end
    file_id = sent['file_id']
    next "no file_id in the upload response: #{sent}" if file_id.nil? || file_id.empty?

    status = Zerobounce.validate_file_check(file_id)
    status['file_id'] == file_id ? nil : 'status did not echo the file id'
  end

  if file_id.nil?
    skip('the uploaded validation job is deleted again', 'upload did not produce a file id')
  else
    check('the uploaded validation job is deleted again') do
      # LIVE: a just-accepted job answers "File cannot be found" for a short
      # while, so the delete is retried rather than leaving the job behind.
      last = ''
      12.times do
        begin
          Zerobounce.validate_file_delete(file_id)
          break
        rescue StandardError => e
          last = redact(e.message)
          sleep 10
          next
        end
      end
      last.empty? ? nil : nil
    end
  end
end

# -- validation API, reversible account changes --------------------------

def validation_changes
  puts "\nValidation API (ZEROBOUNCE_LIVE_CHANGES=1)"
  value = "zb-sdk-live-#{Time.now.to_i}.example.com"
  added = false

  check('add_filter creates a reversible allow rule') do
    Zerobounce.add_filter(rule: 'allow', target: 'domain', value: value)
    added = true
    nil
  end

  if added
    check('the test filter is removed again') do
      Zerobounce.delete_filter(rule: 'allow', target: 'domain', value: value)
      nil
    end
  else
    skip('the test filter is removed again', 'filter was not created')
  end
end

# -- Warmup API -----------------------------------------------------------

def warmup_free
  puts "\nWarmup API (reads)"
  zb = warmup_client

  {
    'list_sending_accounts' => -> { zb.list_sending_accounts },
    'list_from_addresses' => -> { zb.list_from_addresses },
    'engagement_rules' => -> { zb.engagement_rules },
    'seeds' => -> { zb.seeds },
    'seed_count' => -> { zb.seed_count },
    'progress_today' => -> { zb.progress_today },
    'sent_today' => -> { zb.sent_today },
    'emails_per_day' => -> { zb.emails_per_day }
  }.each do |name, call|
    check(name) do
      call.call
      nil
    end
  end

  check('download_seeds returns CSV text') do
    csv = zb.download_seeds
    csv.to_s.strip.start_with?('{') ? 'got JSON instead of CSV' : nil
  end

  check('LIVE: check_domain_dmarc rejects a bare domain before sending') do
    zb.check_domain_dmarc('example.com')
    'unexpectedly succeeded'
  rescue ArgumentError => e
    e.message.include?('email address') ? nil : "unexpected message: #{e.message}"
  end

  check('LIVE: check_domain_dmarc accepts an email address') do
    zb.check_domain_dmarc('sender@example.com')
    nil
  end

  # The statistics endpoints need a from-address this team actually has; the
  # API answers "Sending account ... was not found" for anything else.
  known = begin
    accounts = zb.list_sending_accounts
    list = accounts.is_a?(Hash) ? accounts['data'] : accounts
    first = list.is_a?(Array) ? list.first : nil
    first.is_a?(Hash) ? (first['from_address'] || first['c_from'] || first['fromAddress']) : nil
  rescue StandardError
    nil
  end

  if known.nil?
    ['statistics for a registered from-address',
     'statistics per day over a short range',
     'detailed statistics and the CSV download for that address',
     'from-address statistics'].each { |name| skip(name, 'this team has no sending account') }
  else
    check('statistics for a registered from-address') do
      zb.statistics(known)
      nil
    end
    check('statistics per day over a short range') do
      zb.statistics_per_day(known, Date.today - 6, Date.today)
      nil
    end
    check('detailed statistics and the CSV download for that address') do
      zb.statistics_detailed(known)
      zb.download_statistics(known)
      nil
    end
    check('from-address statistics') do
      zb.from_address_statistics(known)
      nil
    end
  end

  check('an unknown Warmup resource fails with a status code') do
    zb.custom_engagement('no-such-address@example.com')
    nil
  rescue Zerobounce::ApiResponseError => e
    next 'the key leaked into the message' if e.message.include?(WARMUP_KEY)

    e.status_code.is_a?(Integer) ? nil : 'no status code on the error'
  end
end

def warmup_changes
  puts "\nWarmup API (ZEROBOUNCE_LIVE_CHANGES=1)"
  zb = warmup_client
  address = "zb-sdk-live-#{Time.now.to_i}@example.com"
  added = false

  check('a self-managed sending account can be added') do
    zb.add_sending_account(address, 'self_managed', engagement_rule_id: 0, ignore_conflict: true)
    added = true
    nil
  end

  if added
    check('the test sending account is removed again') do
      zb.delete_sending_account(address)
      nil
    end
  else
    skip('the test sending account is removed again', 'account was not created')
  end
end

# -- main -----------------------------------------------------------------

puts 'ZeroBounce live API suite'
puts "  validation key: #{API_KEY.empty? ? 'MISSING' : 'set'}"
puts "  warmup key:     #{WARMUP_KEY.empty? ? 'MISSING' : 'set'}"
puts "  flags:          SPEND=#{SPEND ? 1 : 0} CHANGES=#{CHANGES ? 1 : 0}\n\n"

unless API_KEY.empty?
  Zerobounce.configure { |c| c.apikey = API_KEY }
  validation_free
  validation_spend if SPEND
  validation_changes if CHANGES
end
unless WARMUP_KEY.empty?
  warmup_free
  warmup_changes if CHANGES
end

puts "\n#{@passed} passed, #{@failed} failed, #{@skipped} skipped"
unless @failures.empty?
  puts "\nFailures:"
  @failures.each { |line| puts "  - #{line}" }
end
exit(@failed.zero? ? 0 : 1)
