# frozen_string_literal: true

require 'spec_helper'
require 'socket'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength, Metrics/ModuleLength
# The transport guards on every request path: a body cut short, redirects and
# timeouts. Each sweep enumerates every public request method of the client
# and the Warmup client, and a guard fails when one is missing from it.
module TransportSweep
  FILE = 'spec/fixtures/priority3_finder.csv'
  DONE = 'https://example.com/d'

  def self.csv_io
    StringIO.new("email\na@example.com\n")
  end

  # Every public request method of Zerobounce, called once.
  CALLS = {
    validate: -> { Zerobounce.validate('a@example.com') },
    credits: -> { Zerobounce.credits },
    api_usage: -> { Zerobounce.api_usage(Date.new(2024, 1, 1), Date.new(2024, 1, 2)) },
    activity: -> { Zerobounce.activity('a@example.com') },
    score_email: -> { Zerobounce.score_email('a@example.com') },
    validate_batch: -> { Zerobounce.validate_batch(['a@example.com']) },
    validate_file_send: -> { Zerobounce.validate_file_send(FILE) },
    validate_file_send_stream: -> { Zerobounce.validate_file_send_stream(csv_io, 'f.csv') },
    validate_file_check: -> { Zerobounce.validate_file_check('f1') },
    validate_file_get: -> { Zerobounce.validate_file_get('f1') },
    validate_file_delete: -> { Zerobounce.validate_file_delete('f1') },
    scoring_file_send: -> { Zerobounce.scoring_file_send(FILE) },
    scoring_file_send_stream: -> { Zerobounce.scoring_file_send_stream(csv_io, 'f.csv') },
    scoring_file_get: -> { Zerobounce.scoring_file_get('f1') },
    scoring_file_check: -> { Zerobounce.scoring_file_check('f1') },
    scoring_file_delete: -> { Zerobounce.scoring_file_delete('f1') },
    guessformat: -> { Zerobounce.guessformat('example.com') },
    find_email: -> { Zerobounce.find_email('Ann', domain: 'example.com') },
    find_domain: -> { Zerobounce.find_domain(domain: 'example.com') },
    send_email_finder_file: -> { Zerobounce.send_email_finder_file(FILE, domain_column: 1, first_name_column: 2) },
    email_finder_file_status: -> { Zerobounce.email_finder_file_status('f1') },
    email_finder_file_get: -> { Zerobounce.email_finder_file_get('f1') },
    email_finder_file_delete: -> { Zerobounce.email_finder_file_delete('f1') },
    send_domain_search_file: -> { Zerobounce.send_domain_search_file(FILE, domain_column: 1) },
    domain_search_file_status: -> { Zerobounce.domain_search_file_status('f1') },
    domain_search_file_get: -> { Zerobounce.domain_search_file_get('f1') },
    domain_search_file_delete: -> { Zerobounce.domain_search_file_delete('f1') },
    send_list_evaluator_file: -> { Zerobounce.send_list_evaluator_file(FILE, email_address_column: 1) },
    get_list_evaluator_result: -> { Zerobounce.get_list_evaluator_result('f1') },
    send_evaluated_file: -> { Zerobounce.send_evaluated_file('f1') },
    add_filter: -> { Zerobounce.add_filter(rule: 'allow', target: 'email', value: 'a@example.com') },
    list_filters: -> { Zerobounce.list_filters },
    delete_filter: -> { Zerobounce.delete_filter(rule: 'allow', target: 'email', value: 'a@example.com') },
    list_s3_files: -> { Zerobounce.list_s3_files },
    validate_s3_file: -> { Zerobounce.validate_s3_file(file_name: 'f.csv', return_url: DONE) },
    score_s3_file: -> { Zerobounce.score_s3_file(file_name: 'f.csv', return_url: DONE) },
    export_s3_file: -> { Zerobounce.export_s3_file(file_id: 'f1') },
    email_finder_s3_file: -> { Zerobounce.email_finder_s3_file('f.csv', true, return_url: DONE) },
    domain_search_s3_file: -> { Zerobounce.domain_search_s3_file('f.csv', true, return_url: DONE) },
    validate_sftp_file: -> { Zerobounce.validate_sftp_file('f.csv', true, return_url: DONE) },
    score_sftp_file: -> { Zerobounce.score_sftp_file('f.csv', true, return_url: DONE) },
    email_finder_sftp_file: -> { Zerobounce.email_finder_sftp_file('f.csv', true, return_url: DONE) },
    domain_search_sftp_file: -> { Zerobounce.domain_search_sftp_file('f.csv', true, return_url: DONE) },
    export_sftp_file: -> { Zerobounce.export_sftp_file(file_id: 'f1') },
    inbox_placement_providers: -> { Zerobounce.inbox_placement_providers },
    inbox_placement_test_types: -> { Zerobounce.inbox_placement_test_types },
    create_inbox_placement_test: -> { Zerobounce.create_inbox_placement_test('Test', test_type: 2) },
    inbox_placement_test: -> { Zerobounce.inbox_placement_test('1') },
    list_inbox_placement_tests: -> { Zerobounce.list_inbox_placement_tests },
    delete_inbox_placement_test: -> { Zerobounce.delete_inbox_placement_test('1') },
    inbox_placement_webhook: -> { Zerobounce.inbox_placement_webhook },
    set_inbox_placement_webhook: -> { Zerobounce.set_inbox_placement_webhook('https://example.com/hook') }
  }.freeze

  NOT_REQUESTS = %i[configuration config configure configuration= with_api_key
                    get_file_json_indicates_error? zb_request].freeze

  # Every public method of Zerobounce::Warmup, called once.
  WARMUP_CALLS = {
    list_sending_accounts: ->(w) { w.list_sending_accounts },
    get_sending_account: ->(w) { w.get_sending_account('a@b.com') },
    add_sending_account: ->(w) { w.add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 0) },
    update_sending_account: ->(w) { w.update_sending_account('a@b.com', 1, 4, true) },
    delete_sending_account: ->(w) { w.delete_sending_account('a@b.com') },
    change_from_address: ->(w) { w.change_from_address('a@b.com', 'c@d.com') },
    list_from_addresses: ->(w) { w.list_from_addresses },
    engagement_rules: ->(w) { w.engagement_rules },
    set_engagement_rule: ->(w) { w.set_engagement_rule('a@b.com', 2) },
    custom_engagement: ->(w) { w.custom_engagement('a@b.com') },
    create_custom_engagement: ->(w) { w.create_custom_engagement('a@b.com', 10, 10, 5) },
    update_custom_engagement: ->(w) { w.update_custom_engagement('a@b.com', 10, 10, 5) },
    delete_custom_engagement: ->(w) { w.delete_custom_engagement('a@b.com', 1) },
    seeds: ->(w) { w.seeds },
    download_seeds: ->(w) { w.download_seeds },
    seed_count: ->(w) { w.seed_count },
    progress_today: ->(w) { w.progress_today },
    sent_today: ->(w) { w.sent_today },
    emails_per_day: ->(w) { w.emails_per_day },
    statistics: ->(w) { w.statistics('a@b.com') },
    statistics_per_day: ->(w) { w.statistics_per_day('a@b.com', '2026-09-01', '2026-09-14') },
    statistics_detailed: ->(w) { w.statistics_detailed('a@b.com') },
    download_statistics: ->(w) { w.download_statistics('a@b.com') },
    from_address_statistics: ->(w) { w.from_address_statistics('a@b.com') },
    check_domain_dmarc: ->(w) { w.check_domain_dmarc('a@b.com') },
    test_smtp_configuration: ->(w) { w.test_smtp_configuration('a@b.com', 'u', 'p', 'smtp.example.com', 587) }
  }.freeze

  # Points every base URL of the client at +root+.
  def self.configure(api_key, root)
    Zerobounce.configure do |c|
      c.apikey = api_key
      c.api_root_url = "#{root}/v2"
      c.bulk_api_root_url = "#{root}/v2"
      c.bulk_root_url = root
      c.list_evaluator_root_url = "#{root}/v2/listevaluator"
      c.inbox_placement_root_url = "#{root}/api/ipt"
    end
  end

  def self.warmup(api_key, root)
    Zerobounce::Warmup.new(api_key).tap { |w| w.instance_variable_set(:@root, "#{root}/api/v1/warmup") }
  end
end

# A loopback HTTP server on a raw socket: reads each request, writes the bytes
# the block returns for its request line, and closes the connection.
class RawSocketServer
  attr_reader :hits

  def initialize(&responder)
    @server = TCPServer.new('127.0.0.1', 0)
    @hits = 0
    @thread = Thread.new { serve(responder) }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def close
    @thread.kill
    @server.close
  end

  private

  def serve(responder)
    loop do
      client = @server.accept
      @hits += 1
      answer(client, responder)
    end
  end

  def answer(client, responder)
    client.write(responder.call(read_request(client)))
  rescue StandardError
    nil
  ensure
    client.close
  end

  # The request line, after the whole request (headers and body) is read.
  def read_request(client)
    data = +''
    data << client.readpartial(65_536) until data.include?("\r\n\r\n")
    head, body = data.split("\r\n\r\n", 2)
    length = head[/^content-length:\s*(\d+)/i, 1].to_i
    body << client.readpartial(65_536) while body.bytesize < length
    head.lines.first.to_s
  end
end

describe 'Transport guards on every request path' do
  let(:api_key) { 'guard-key-123' }

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before { allow(Zerobounce).to receive(:warn) }

  it 'sweeps every public request method of the client' do
    expect(Zerobounce.singleton_methods.sort - TransportSweep::NOT_REQUESTS - TransportSweep::CALLS.keys).to eq([])
  end

  it 'sweeps every public method of the Warmup client' do
    expect(Zerobounce::Warmup.public_instance_methods(false).sort - %i[inspect] - TransportSweep::WARMUP_CALLS.keys)
      .to eq([])
  end

  # Net::HTTP returns what arrived when the connection closes before
  # Content-Length bytes (ignore_eof), so a 200 with a cut-short body would
  # otherwise read as a complete result.
  describe 'a body cut short after its 200 header' do
    csv = "email,status\na@b.c,valid\n" # 25 bytes
    json = '{"Credits":"5","a":"bbb"}' # 25 bytes, valid JSON on its own

    server = nil
    before(:all) do
      WebMock.disable!
      server = RawSocketServer.new do |request_line|
        file = request_line.include?('getfile') || request_line.include?('/download')
        type, body = file ? ['application/octet-stream', csv] : ['application/json', json]
        "HTTP/1.1 200 OK\r\nContent-Type: #{type}\r\nContent-Length: 1000\r\nConnection: close\r\n\r\n#{body}"
      end
    end

    after(:all) do
      server.close
      WebMock.enable!
    end

    before do
      allow(Zerobounce::BaseRequest).to receive(:__require_https__) { |url| url }
      TransportSweep.configure(api_key, server.url)
    end

    def expect_cut_short(&call)
      expect(&call).to raise_error(Zerobounce::ApiResponseError) { |error|
        expect([error.status_code, error.message]).to match([0, include('25 of 1000 bytes')])
        expect(error.full_message(highlight: false)).not_to include(api_key)
      }
    end

    TransportSweep::CALLS.each do |name, call|
      it "raises for #{name}" do
        expect_cut_short { call.call }
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "raises for Warmup##{name}" do
        warmup = TransportSweep.warmup(api_key, server.url)
        expect_cut_short { call.call(warmup) }
      end
    end
  end

  # A 3xx WITH a Location header: a client that followed redirects would
  # reach the second host, carrying the key.
  describe 'redirects' do
    statuses = [301, 302, 303, 307, 308]

    def stub_redirect(status)
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: status, body: '', headers: { 'Location' => 'https://second.example/landed' })
      stub_request(:any, %r{\Ahttps://second\.example/})
        .to_return(status: 200, body: '{"Credits":"999"}', headers: { 'Content-Type' => 'application/json' })
    end

    def expect_refused(status, &call)
      expect(&call).to raise_error(StandardError) { |error|
        expect(error.message).not_to include('999')
      }
      expect(a_request(:any, %r{\Ahttps://second\.example/})).not_to have_been_made, "HTTP #{status} was followed"
    end

    before { TransportSweep.configure(api_key, 'https://first.example') }

    TransportSweep::CALLS.each do |name, call|
      it "are not followed by #{name}" do
        statuses.each do |status|
          WebMock.reset!
          stub_redirect(status)
          expect_refused(status) { call.call }
        end
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "are not followed by Warmup##{name}" do
        statuses.each do |status|
          WebMock.reset!
          stub_redirect(status)
          expect_refused(status) { call.call(TransportSweep.warmup(api_key, 'https://first.example')) }
        end
      end
    end
  end

  # Every request is sent with an explicit timeout: RestClient's own
  # defaults would otherwise apply.
  describe 'timeouts' do
    let(:sent) { [] }

    before do
      TransportSweep.configure(api_key, 'https://first.example')
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: 200, body: '{"success":true}', headers: { 'Content-Type' => 'application/json' })
      allow(RestClient::Request).to receive(:execute).and_wrap_original do |original, *args, **kwargs, &block|
        sent << (args.first || kwargs)
        original.call(*args, **kwargs, &block)
      end
    end

    def expect_timeouts(name)
      begin
        yield
      rescue StandardError
        nil # Only the options the request went out with matter here.
      end
      expect(sent).not_to be_empty, "#{name} sent no request"
      sent.each { |options| expect(options[:timeout]).to eq(120), "#{name} was sent without its timeout" }
    end

    TransportSweep::CALLS.each do |name, call|
      it "are set by #{name}" do
        expect_timeouts(name) { call.call }
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "are set by Warmup##{name}" do
        expect_timeouts(name) { call.call(TransportSweep.warmup(api_key, 'https://first.example')) }
      end
    end
  end

  # An HTML page (a proxy's or Cloudflare's "Access denied") on a 200 is an
  # error carrying that status on every request path, never a result.
  describe 'an HTML page on a 200' do
    page = '<!DOCTYPE html><html><head><title>Access denied</title></head><body>no</body></html>'

    before do
      TransportSweep.configure(api_key, 'https://first.example')
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: 200, body: page, headers: { 'Content-Type' => 'text/html; charset=UTF-8' })
    end

    def expect_page_error(&call)
      expect(&call).to raise_error(Zerobounce::ApiResponseError) { |error|
        expect([error.status_code, error.message]).to match([200, include('Access denied')])
      }
    end

    TransportSweep::CALLS.each do |name, call|
      it "is an error with the status for #{name}" do
        expect_page_error { call.call }
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "is an error with the status for Warmup##{name}" do
        expect_page_error { call.call(TransportSweep.warmup(api_key, 'https://first.example')) }
      end
    end
  end
  describe 'a JSON content type with a body that is not valid JSON, on a 200' do
    before do
      TransportSweep.configure(api_key, 'https://first.example')
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: 200, body: '{"success":', headers: { 'Content-Type' => 'application/json' })
    end

    def expect_error_on_ok(&call)
      expect(&call).to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.status_code).to eq(200) }
    end

    TransportSweep::CALLS.each do |name, call|
      it "is an error with the status for #{name}" do
        expect_error_on_ok { call.call }
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "is an error with the status for Warmup##{name}" do
        expect_error_on_ok { call.call(TransportSweep.warmup(api_key, 'https://first.example')) }
      end
    end
  end

  # A response body that quotes the key (an API message naming the key, a
  # proxy echoing the request URL, an HTML title) must not hand it to the
  # caller, whatever the status: every error the SDK raises from a body is
  # redacted, in the key's raw, URL-encoded and JSON-escaped forms. The key
  # holds each character those encodings change: '"', '/', '+' and '%'.
  describe 'a response body that quotes the API key' do
    echo_key = 'echo"key/4+2%25'
    encoded = ERB::Util.url_encode(echo_key)
    escaped = JSON.generate(echo_key)[1..-2] # echo\"key/4+2%25
    # echo\"key\/4+2%25, as some servers write JSON (escape_slash: the json
    # 2.6 name of script_safe, still accepted by later versions)
    escaped_slash = JSON.generate(echo_key, escape_slash: true)[1..-2]
    forms = [echo_key, encoded, CGI.escape(echo_key), escaped, escaped_slash].freeze
    json = 'application/json'
    bodies = {
      '200 HTML title' => [200, 'text/html', "<html><head><title>Denied #{echo_key}</title></head></html>"],
      '400 text quoting the URL' => [400, 'text/plain', "Bad request: https://first.example/v2/x?api_key=#{encoded}"],
      '400 text quoting the raw key' => [400, 'text/plain', "Bad request for #{echo_key}"]
    }
    { 'escaped' => escaped, 'escaped \\/' => escaped_slash }.each do |how, form|
      bodies.merge!(
        "200 {\"error\"} #{how}" => [200, json, %({"error":"Invalid API key #{form}"})],
        "200 {\"success\":false} #{how}" => [200, json, %({"success":false,"message":"Invalid API key #{form}"})],
        "200 batch \"all\" error #{how}" =>
          [200, json, %({"email_batch":[],"errors":[{"email_address":"all","error":"Invalid API key #{form}"}]})],
        "200 JSON cut off #{how}" => [200, json, %({"error":"Invalid API key #{form}")],
        "400 {\"error\"} #{how}" => [400, json, %({"error":"Invalid API key #{form}"})]
      )
    end
    bodies.freeze

    def stub_body(status, type, body)
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: status, body: body, headers: { 'Content-Type' => type })
    end

    # Everything a caller or an uncaught-exception printer reads off the
    # error, down the whole #cause chain.
    def visible_text(error)
      parts = []
      while error
        parts << error.message << error.inspect << error.full_message(highlight: false)
        error = error.cause
      end
      parts.join("\n")
    end

    def expect_redacted(label, forms)
      yield
    rescue StandardError => e
      text = visible_text(e)
      forms.each { |form| expect(text).not_to include(form), "#{label}: #{e.class}: #{text}" }
    end

    TransportSweep::CALLS.each do |name, call|
      it "keeps the key out of every error from #{name}" do
        TransportSweep.configure(echo_key, 'https://first.example')
        bodies.each do |label, (status, type, body)|
          WebMock.reset!
          stub_body(status, type, body)
          expect_redacted(label, forms) { call.call }
        end
      end
    end

    TransportSweep::WARMUP_CALLS.each do |name, call|
      it "keeps the key out of every error from Warmup##{name}" do
        bodies.each do |label, (status, type, body)|
          WebMock.reset!
          stub_body(status, type, body)
          expect_redacted(label, forms) { call.call(TransportSweep.warmup(echo_key, 'https://first.example')) }
        end
      end
    end

    # The sweep above only checks the errors that are raised; these bodies
    # are errors on every call of the client, so each must raise.
    it 'raises for each error body on every call of the client' do
      TransportSweep.configure(echo_key, 'https://first.example')
      bodies.reject { |label, _| label.start_with?('200 batch "all" error') }.each do |label, (status, type, body)|
        TransportSweep::CALLS.each do |name, call|
          WebMock.reset!
          stub_body(status, type, body)
          expect { call.call }.to raise_error(StandardError), "#{name} returned for #{label}"
        end
      end
    end
  end
end

# What an error carries, not only what it prints: every string reachable from
# the raised error, its #cause chain and their instance variables (a
# RestClient error keeps the response, whose request keeps the URL and the
# API-Key header). The key and the SMTP credentials must be in none of them.
module ErrorContents
  module_function

  LEAVES = [Symbol, Numeric, NilClass, TrueClass, FalseClass, Module].freeze

  def strings(object, seen = {}, depth = 0, out = [])
    return out if depth > 12 || seen.key?(object.__id__) || LEAVES.any? { |leaf| object.is_a?(leaf) }

    seen[object.__id__] = true
    out << object.to_s if object.is_a?(String) # RestClient::Response is a String with ivars
    children(object).each { |child| strings(child, seen, depth + 1, out) }
    out
  end

  def children(object)
    case object
    when Hash then object.to_a.flatten(1)
    when Array, Struct then object.to_a
    else
      own = object.instance_variables.map { |name| object.instance_variable_get(name) }
      object.is_a?(Exception) ? own + [object.message.to_s, object.cause] : own
    end
  end

  def leaks(error, secrets)
    found = strings(error)
    secrets.flat_map { |s| [s, CGI.escape(s), ERB::Util.url_encode(s)] }.uniq.select do |form|
      found.any? { |text| text.include?(form) }
    end
  end
end

describe 'errors from the Warmup client' do
  key = 'carried+key/0123456789'
  password = 'smtp+pass/0123456789'
  root = 'https://first.example'

  def stub_any
    stub_request(:any, %r{\Ahttps://first\.example/})
  end

  calls = TransportSweep::WARMUP_CALLS.merge(
    test_smtp_configuration: ->(w) { w.test_smtp_configuration('a@b.com', 'u', password, 'smtp.example.com', 587) }
  )

  it 'sweeps every public method' do
    expect(Zerobounce::Warmup.public_instance_methods(false).sort - %i[inspect] - calls.keys).to eq([])
  end

  text = { 'Content-Type' => 'text/plain' }
  json = { 'Content-Type' => 'application/json' }
  failures = {
    '400 text' => -> { stub_any.to_return(status: 400, body: 'Bad request', headers: text) },
    '404 JSON' => -> { stub_any.to_return(status: 404, body: '{"detail":"Not found"}', headers: json) },
    '429' => -> { stub_any.to_return(status: 429, body: '', headers: {}) },
    '500 JSON' => -> { stub_any.to_return(status: 500, body: '{"error":"boom"}', headers: json) },
    'read timeout' => -> { stub_any.to_raise(Net::ReadTimeout) },
    'open timeout' => -> { stub_any.to_raise(Net::OpenTimeout) }
  }.freeze

  calls.each do |name, call|
    it "raises an ApiResponseError carrying no secret from Warmup##{name}" do
      failures.each do |label, stub|
        WebMock.reset!
        instance_exec(&stub)
        warmup = TransportSweep.warmup(key, root)
        expect { call.call(warmup) }.to raise_error(Zerobounce::ApiResponseError) { |error|
          status = label.to_i
          expect(error.status_code).to eq(status), "#{label}: status #{error.status_code}"
          expect(error.message).not_to be_empty, label
          expect(ErrorContents.leaks(error, [key, password])).to eq([]), "#{label}: #{error.class}: #{error.message}"
        }
      end
    end
  end
end

describe 'errors from the client' do
  key = 'carried+key/0123456789'

  text = { 'Content-Type' => 'text/plain' }
  json = { 'Content-Type' => 'application/json' }
  failures = {
    '400 text' => ->(s) { s.to_return(status: 400, body: 'Bad request', headers: text) },
    '404 JSON' => ->(s) { s.to_return(status: 404, body: '{"error":"Not found"}', headers: json) },
    '500 JSON' => ->(s) { s.to_return(status: 500, body: '{"error":"boom"}', headers: json) },
    'read timeout' => ->(s) { s.to_raise(Net::ReadTimeout) }
  }.freeze

  before { TransportSweep.configure(key, 'https://first.example') }

  # Up to 3.0.1 the RestClient error raised for an HTTP error status kept its
  # response's request, whose URL or payload holds api_key.
  TransportSweep::CALLS.each do |name, call|
    it "carries no key in any error from #{name}" do
      failures.each do |label, stub|
        WebMock.reset!
        stub.call(stub_request(:any, %r{\Ahttps://first\.example/}))
        expect { call.call }.to raise_error(StandardError) { |error|
          expect(ErrorContents.leaks(error, [key])).to eq([]), "#{label}: #{error.class}: #{error.message}"
        }
      end
    end
  end
end

# Body checks that a mutation once removed without a failing spec: the
# text/html content type on its own, a "success" sent as the string "false",
# a getfile JSON error under a CSV content type, and the Warmup CSV checks.
describe 'body checks on every path' do
  root = 'https://first.example'
  downloads = TransportSweep::CALLS.keys.select { |name| name.to_s.end_with?('_file_get') }
  getfile_errors = ['{"success":false,"message":"File cannot be found."}',
                    %(  \n{"error":"File cannot be found."})].freeze
  csv_json_bodies = ['{"error":"c_from not found"}', %(  \n{"success":false,"message":"no seeds"}), '[]'].freeze
  empty_bodies = ['', "  \n"].freeze

  def stub_any(status, type, body)
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: status, body: body, headers: { 'Content-Type' => type })
  end

  before do
    TransportSweep.configure('body-key', root)
    allow(Zerobounce).to receive(:warn)
  end

  it 'finds the four result-file downloads' do
    expect(downloads.size).to eq(4)
  end

  # A body every path would otherwise accept, under text/html: JSON for the
  # JSON calls, a CSV line for the downloads. Only the content type says
  # it is a page.
  TransportSweep::CALLS.each do |name, call|
    it "treats a text/html answer as an error with status 200 on #{name}" do
      body = if downloads.include?(name)
               "email,status\na@example.com,valid\n"
             else
               '{"success":true,"Credits":"5","file_id":"f1","email_batch":[],"status":"valid"}'
             end
      stub_any(200, 'text/html; charset=utf-8', body)
      expect { call.call }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.status_code).to eq(200)
      }
    end
  end

  %i[download_seeds download_statistics].each do |name|
    call = TransportSweep::WARMUP_CALLS.fetch(name)
    it "treats a text/html answer as an error with status 200 on Warmup##{name}" do
      stub_any(200, 'text/html', "seed,provider\na@b.com,gmail\n")
      expect { call.call(TransportSweep.warmup('body-key', root)) }
        .to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.status_code).to eq(200) }
    end
  end

  # The Warmup JSON calls: a body that parses as JSON, under text/html.
  (TransportSweep::WARMUP_CALLS.keys - %i[download_seeds download_statistics]).each do |name|
    it "treats a text/html answer as an error with status 200 on Warmup##{name}" do
      stub_any(200, 'text/html; charset=utf-8', '{"a":1}')
      expect { TransportSweep::WARMUP_CALLS[name].call(TransportSweep.warmup('body-key', root)) }
        .to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.status_code).to eq(200) }
    end
  end

  it 'treats "success": "false" (a string, any case) as an error on every JSON call' do
    accepted = []
    ['{"success":"false","file_id":"f1"}', '{"success":" False ","file_id":"f1"}'].each do |body|
      (TransportSweep::CALLS.keys - downloads).each do |name|
        WebMock.reset!
        stub_any(200, 'application/json', body)
        begin
          TransportSweep::CALLS[name].call
          accepted << [name, body]
        rescue Zerobounce::ApiResponseError => e
          expect(e.status_code).to eq(200), name.to_s
        end
      end
    end
    # Calls whose answer has no "success" field still raise: the field is read
    # wherever it appears.
    expect(accepted).to eq([])
  end

  downloads.each do |name|
    it "treats a JSON error under text/csv as an error on #{name}" do
      getfile_errors.each do |body|
        WebMock.reset!
        stub_any(200, 'text/csv', body)
        expect { TransportSweep::CALLS[name].call }.to raise_error(Zerobounce::ApiResponseError) { |error|
          expect(error.status_code).to eq(200)
          expect(error.message).to include('File cannot be found.')
        }
      end
    end
  end

  %i[download_seeds download_statistics].each do |name|
    it "treats a JSON body under text/csv as an error on Warmup##{name}" do
      csv_json_bodies.each do |body|
        WebMock.reset!
        stub_any(200, 'text/csv', body)
        expect { TransportSweep::WARMUP_CALLS[name].call(TransportSweep.warmup('body-key', root)) }
          .to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.status_code).to eq(200) }
      end
    end

    it "treats an empty body as an error on Warmup##{name}" do
      empty_bodies.each do |body|
        WebMock.reset!
        stub_any(200, 'text/csv', body)
        expect { TransportSweep::WARMUP_CALLS[name].call(TransportSweep.warmup('body-key', root)) }
          .to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.status_code).to eq(200) }
      end
    end
  end
end

# The SMTP username and password are masked like the key, in every form.
describe 'SMTP secrets quoted in a body' do
  password = 'pw"with/slash+plus%41'
  username = 'user"name/x+y%42'

  it 'are masked raw, URL-encoded and JSON-escaped' do
    # The last one is written \u00e9 by a server that escapes non-ASCII.
    [password, username, "pw\u00e9-unicode"].each do |secret|
      escaped = JSON.generate(secret)[1..-2]
      forms = [secret, ERB::Util.url_encode(secret), CGI.escape(secret), escaped,
               JSON.generate(secret, escape_slash: true)[1..-2], JSON.generate(secret, ascii_only: true)[1..-2]].uniq
      forms[1..].each do |form|
        [[400, %({"error":"login failed: #{form}"})], [500, "login failed: #{form}"]].each do |status, body|
          WebMock.reset!
          stub_request(:any, %r{\Ahttps://first\.example/})
            .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
          warmup = TransportSweep.warmup('smtp-key', 'https://first.example')
          expect { warmup.test_smtp_configuration('a@b.com', username, secret, 'smtp.example.com', 587) }
            .to raise_error(Zerobounce::ApiResponseError) { |error|
              expect(ErrorContents.leaks(error, [secret]) + forms.select { |f| error.message.include?(f) })
                .to eq([]), "#{status} #{body}: #{error.message}"
            }
        end
      end
    end
  end
end

# Each spelling a secret can take in an echoed body, composed here from the
# encoders themselves: {raw, JSON, JSON with \/} (each JSON form with
# non-ASCII as is or as \uXXXX) x {as is, URL-encoded with %20, with +}, each
# JSON form escaped twice, and #inspect. Dropping any one generator from
# ApiKey.secret_forms fails. The first secret holds every character an
# encoding changes; the second a non-ASCII character, a space, "/", '"' and
# the "#{" that Ruby's #inspect escapes and JSON does not.
describe 'every spelling of a secret echoed in a body' do
  root = 'https://first.example'
  secrets = [%(a b"/+%&=<>'\\), "pw\u00e9 /\"\#{x}"].freeze

  def self.escapers
    escapers = { 'raw' => ->(text) { text } }
    [false, true].product([false, true]).each do |slash, ascii|
      escapers["JSON#{' \\/' if slash}#{' \\uXXXX' if ascii}"] = lambda do |text|
        # escape_slash is the generator's own "\/" (json >= 2.6, as both lockfiles pin).
        JSON.generate(text, ascii_only: ascii, escape_slash: slash)[1..-2]
      end
    end
    escapers
  end

  def self.url_encoders
    { '' => ->(text) { text }, ', URL-encoded %20' => ->(text) { ERB::Util.url_encode(text) },
      ', URL-encoded +' => ->(text) { CGI.escape(text) } }
  end

  def self.spellings(secret)
    spellings = { 'inspect' => secret.inspect[1..-2] }
    escapers.each do |escape_label, escape|
      url_encoders.each { |url_label, encode| spellings[escape_label + url_label] = encode.call(escape.call(secret)) }
      spellings["#{escape_label}, twice"] = escape.call(escape.call(secret)) unless escape_label == 'raw'
    end
    spellings
  end

  it 'composes every spelling' do
    expect(self.class.spellings(secrets[0]).size).to eq(1 + (5 * 3) + 4)
  end

  def stub_echo(text)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 400, body: "rejected: #{text}", headers: { 'Content-Type' => 'text/plain' })
  end

  # Otherwise dropping that spelling from ApiKey.secret_forms could go unseen.
  it 'gives each spelling a value no other spelling has, for one of the secrets' do
    shared = self.class.spellings(secrets[0]).keys.select do |label|
      secrets.all? do |secret|
        forms = self.class.spellings(secret)
        forms.count { |_, form| form == forms[label] } > 1
      end
    end
    expect(shared).to eq([])
  end

  secrets.each_with_index do |secret, index|
    spellings(secret).each do |label, form|
      it "masks secret #{index + 1} written #{label} whole" do
        expect(Zerobounce::ApiKey.redact("<#{form}>", [secret])).to eq('<***>')
      end

      it "masks secret #{index + 1} written #{label}, as the API key and as the SMTP password" do
        stub_echo(form)
        TransportSweep.configure(secret, root)
        expect { Zerobounce.credits }.to raise_error(RestClient::BadRequest) { |error|
          expect(error.message).not_to include(form)
        }

        stub_echo(form)
        warmup = TransportSweep.warmup('smtp-key', root)
        expect { warmup.test_smtp_configuration('a@b.com', 'user', secret, 'smtp.example.com', 587) }
          .to raise_error(Zerobounce::ApiResponseError) { |error| expect(error.message).not_to include(form) }
      end
    end
  end
end

# A Marshal or YAML dump of an object holding the key would carry it to
# wherever the dump is written, so it is refused.
describe 'serialising an object that holds the API key' do
  require 'yaml'

  key = 'dump-key-0123456789'
  objects = {
    'Configuration' => -> { Zerobounce::Configuration.new.tap { |c| c.apikey = key } },
    'Client' => -> { Zerobounce::Client.new(key) },
    'Warmup' => -> { Zerobounce::Warmup.new(key) }
  }

  objects.each do |label, build|
    it "refuses Marshal.dump of a #{label}" do
      expect { Marshal.dump(build.call) }
        .to raise_error(TypeError) { |error| expect(error.message).not_to include(key) }
    end

    it "refuses YAML.dump of a #{label}" do
      expect { YAML.dump(build.call) }.to raise_error(TypeError) { |error| expect(error.message).not_to include(key) }
    end

    it "still copies a #{label} with dup" do
      expect(build.call.dup).to be_a(build.call.class)
    end
  end
end
# E7: the shared strict JSON corpus. spec/fixtures/strict-json-corpus.tsv is a
# byte-identical copy of sdk-docs/skills/zerobounce-sdk/references/
# strict-json-corpus.tsv (zerobounce/sdk-docs); refresh it from there. Each
# line's second field is a JSON-encoded string holding the exact body.
module StrictJsonCorpus
  FILE = File.expand_path('fixtures/strict-json-corpus.tsv', __dir__)

  def self.rows
    File.readlines(FILE, encoding: 'UTF-8', chomp: true).reject { |line| line.empty? || line.start_with?('#') }
        .map do |line|
      verdict, encoded = line.split("\t", 2)
      [verdict, JSON.parse(encoded, quirks_mode: true)]
    end
  end

  # Downloads are not JSON calls: any JSON body is an error there.
  DOWNLOADS = %i[validate_file_get scoring_file_get email_finder_file_get domain_search_file_get].freeze
  WARMUP_DOWNLOADS = %i[download_seeds download_statistics].freeze

  def self.calls(root)
    TransportSweep::CALLS.except(*DOWNLOADS).map { |name, call| [name.to_s, call] } +
      TransportSweep::WARMUP_CALLS.except(*WARMUP_DOWNLOADS).map do |name, call|
        ["warmup.#{name}", -> { call.call(TransportSweep.warmup('corpus-key', root)) }]
      end
  end

  # An empty 200 (zero bytes) is the documented empty success of the Warmup
  # calls and of delete_inbox_placement_test (check E8); a blank body is never
  # empty. Every Inbox Placement call here still returns nil for an empty
  # body: an open decision (E8), not part of the JSON check.
  def self.empty_success?(name, body)
    body.empty? && (name.start_with?('warmup.') || name.include?('inbox_placement'))
  end
end

describe 'the strict JSON corpus on every JSON call' do
  root = 'https://first.example'

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('corpus-key', root)
  end

  def answer(body)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body.b, headers: { 'Content-Type' => 'application/json' })
  end

  it 'has both verdicts' do
    verdicts = StrictJsonCorpus.rows.map(&:first)
    expect(verdicts.uniq.sort).to eq(%w[ACCEPT REJECT])
    expect(verdicts.count('REJECT')).to be > 30
  end

  it 'rejects every REJECT body with an ApiResponseError carrying status 200' do
    wrong = []
    StrictJsonCorpus.rows.select { |verdict, _| verdict == 'REJECT' }.each do |_, body|
      answer(body)
      StrictJsonCorpus.calls(root).each do |name, call|
        next if StrictJsonCorpus.empty_success?(name, body)

        begin
          call.call
          wrong << [name, body, 'accepted']
        rescue Zerobounce::ApiResponseError => e
          wrong << [name, body, e.status_code] unless e.status_code == 200
        rescue StandardError => e
          wrong << [name, body, e.class.name]
        end
      end
    end
    expect(wrong).to eq([])
  end

  it 'rejects no ACCEPT body as an API error' do
    wrong = []
    StrictJsonCorpus.rows.select { |verdict, _| verdict == 'ACCEPT' }.each do |_, body|
      answer(body)
      StrictJsonCorpus.calls(root).each do |name, call|
        call.call
      rescue Zerobounce::ApiResponseError => e
        # It parsed: the only API error left is JSON of the wrong shape for
        # the call ("0" is not a validate result), with status 200.
        unless e.status_code == 200 && e.message.include?('unexpected shape')
          wrong << [name, body, e.status_code, e.message]
        end
      rescue StandardError => e
        # A raw language error is never the answer.
        wrong << [name, body, e.class.name]
      end
    end
    expect(wrong).to eq([])
  end

  it 'pins allow_nan: false and checks the untrimmed body' do
    expect { Zerobounce::StrictJson.parse('{"a":NaN}') }.to raise_error(JSON::ParserError)
    expect { Zerobounce::StrictJson.parse("\u{a0}{}") }.to raise_error(JSON::ParserError)
    body = " \t\r\n{\"a\":[1,-0.5e-3,\"\\u00e9\\/\"]}\n"
    expect(Zerobounce::StrictJson.parse(body)).to eq('a' => [1, -0.0005, "\u{e9}/"])
  end
end

# S4/S7: redaction is closed under encoding (standard.md). A secret under any
# sequence of up to three encodings (URL with %20, URL with +, JSON, JSON with
# \/) never survives in any decoded view of the error. The decoder here is the
# spec's own, independent of the SDK's.
module EncodingFuzz
  SECRET = %(k y"/\\+%&=<>'z)

  ENCODERS = {
    'URL %20' => ->(text) { ERB::Util.url_encode(text) },
    'URL +' => ->(text) { CGI.escape(text) },
    'JSON' => ->(text) { JSON.generate(text)[1..-2] },
    'JSON \\/' => ->(text) { JSON.generate(text, escape_slash: true)[1..-2] }
  }.freeze

  SIMPLE = { '"' => '"', '\\' => '\\', '/' => '/', 'b' => "\b", 'f' => "\f", 'n' => "\n", 'r' => "\r",
             't' => "\t" }.freeze

  DECODERS = [
    ->(text) { text.b.gsub(/%([0-9A-Fa-f]{2})/n) { [Regexp.last_match(1)].pack('H2') } },
    ->(text) { text.b.tr('+', ' ').gsub(/%([0-9A-Fa-f]{2})/n) { [Regexp.last_match(1)].pack('H2') } },
    ->(text) { text.b.tr('+', ' ') },
    lambda do |text|
      text.b.gsub(%r{\\(u[0-9a-fA-F]{4}|["\\/bfnrt])}n) do
        escape = Regexp.last_match(1)
        escape.start_with?('u') ? [escape[1..].hex].pack('U').b : SIMPLE.fetch(escape).b
      end
    end
  ].freeze

  def self.views(text)
    views = [text.to_s.b]
    frontier = views
    3.times do
      frontier = frontier.flat_map { |view| DECODERS.map { |decode| decode.call(view) } }.uniq - views
      views += frontier
    end
    views
  end

  # Every sequence of up to three encodings, and random ones (fixed seed).
  def self.forms(secret)
    names = ENCODERS.keys
    sequences = (1..3).flat_map { |depth| names.repeated_permutation(depth).to_a }
    rng = Random.new(8259)
    sequences += Array.new(60) { Array.new(rng.rand(1..3)) { names.sample(random: rng) } }
    sequences.map do |sequence|
      [sequence.join(' > '), sequence.reduce(secret) do |form, name|
                               ENCODERS[name].call(form)
                             end]
    end
  end

  BODIES = [
    ->(form) { [400, 'text/plain', "rejected: #{form}"] },
    ->(form) { [200, 'application/json', %({"error":"Invalid API key #{form}"})] },
    ->(form) { [200, 'application/json', %({"success":false,"message":"rejected #{form}"})] },
    ->(form) { [400, 'application/json', %({"message":"bad request #{form}"})] },
    ->(form) { [200, 'text/html', "<html><title>denied #{form}</title></html>"] }
  ].freeze

  # Message, inspect, every instance variable of the SDK's own error, and the
  # whole cause chain (full_message adds only the backtrace). A RestClient
  # error's #response keeps the server's body as sent: an open decision (S5),
  # not checked here.
  def self.texts(error)
    texts = []
    while error
      texts << error.message << error.inspect
      if error.is_a?(Zerobounce::ApiResponseError)
        texts += error.instance_variables.map { |name| error.instance_variable_get(name).inspect }
      end
      error = error.cause
    end
    texts
  end

  # Each form goes to eight calls drawn at random (fixed seed), so every call
  # meets many forms without sending forms x calls requests.
  def self.leaks(secret, calls, stub) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    rng = Random.new(7)
    leaks = []
    forms(secret).each do |label, form|
      status, type, body = BODIES.sample(random: rng).call(form)
      stub.call(status, type, body)
      calls.to_a.sample(8, random: rng).each do |name, call|
        call.call
      rescue StandardError => e
        leaks << [name, label, status] if texts(e).any? { |text| views(text).any? { |view| view.include?(secret.b) } }
      end
    end
    leaks
  end
end

describe 'a secret echoed under any composition of encodings' do
  root = 'https://first.example'
  secret = EncodingFuzz::SECRET

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before { allow(Zerobounce).to receive(:warn) }

  let(:stub) do
    lambda do |status, type, body|
      WebMock.reset!
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: status, body: body, headers: { 'Content-Type' => type })
    end
  end

  it 'never leaves the API key in an error from the client' do
    TransportSweep.configure(secret, root)
    expect(EncodingFuzz.leaks(secret, TransportSweep::CALLS, stub)).to eq([])
  end

  it 'never leaves the Warmup key in an error from the Warmup client' do
    calls = TransportSweep::WARMUP_CALLS.transform_values do |call|
      lambda {
        call.call(TransportSweep.warmup(secret, root))
      }
    end
    expect(EncodingFuzz.leaks(secret, calls, stub)).to eq([])
  end

  it 'never leaves the SMTP password or username in an error' do
    warmup = TransportSweep.warmup('smtp-key', root)
    username = "smtp#{secret}"
    password_call = { password: -> { warmup.test_smtp_configuration('a@b.com', 'u', secret, 'smtp.example.com', 587) } }
    username_call = { username: lambda {
                                  warmup.test_smtp_configuration('a@b.com', username, 'p', 'smtp.example.com', 587)
                                } }
    expect(EncodingFuzz.leaks(secret, password_call, stub)).to eq([])
    expect(EncodingFuzz.leaks(username, username_call, stub)).to eq([])
  end

  it 'keeps a message that holds no secret' do
    expect(Zerobounce::ApiKey.redact('Invalid email a+b%20c\\/d', [secret])).to eq('Invalid email a+b%20c\\/d')
  end
end

# E7: strict JSON of the wrong shape for the call is an API error with status
# 200 on every typed call of Zerobounce: never a result, a raw NoMethodError /
# TypeError, or an error without a status. The Warmup client returns the API's
# JSON as is (objects, arrays or a bare number), so only its parsing is checked,
# by the corpus spec.
describe 'JSON of the wrong shape on every call' do
  root = 'https://first.example'
  scalars = ['0', '"x"', 'null', 'true', '1.5']
  array_calls = %i[list_filters]
  either_calls = %i[list_s3_files]

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('shape-key', root)
  end

  def answer(body)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  def wrong(bodies_for) # rubocop:disable Metrics/MethodLength
    out = []
    TransportSweep::CALLS.except(*StrictJsonCorpus::DOWNLOADS).each do |name, call|
      bodies_for.call(name).each do |body|
        answer(body)
        begin
          result = call.call
          out << [name, body, 'accepted', result]
        rescue Zerobounce::ApiResponseError => e
          out << [name, body, e.status_code] unless e.status_code == 200
        rescue StandardError => e
          out << [name, body, e.class.name]
        end
      end
    end
    out
  end

  it 'names real calls' do
    expect(TransportSweep::CALLS.keys).to include(*array_calls, *either_calls)
  end

  it 'rejects a scalar or null on every call' do
    expect(wrong(->(_name) { scalars })).to eq([])
  end

  it 'rejects an array where an object is expected' do
    bodies = lambda { |name|
      # Empty, one string, and positional arrays holding a call's own field values in order.
      next [] if array_calls.include?(name) || either_calls.include?(name)

      ['[]', '["x"]', '[{"status":"valid"}]', '["a@example.com",10]', '[true,"3"]', '["a@example.com","valid"]',
       '["2375323"]', '[2375323]']
    }
    expect(wrong(bodies)).to eq([])
  end

  it 'rejects an object where an array is expected' do
    bodies = lambda do |name|
      next ['{}', '{"rule":"block"}'] if array_calls.include?(name)
      next ['{}', '{"success":true}', '{"success":true,"files":5}'] if either_calls.include?(name)

      []
    end
    expect(wrong(bodies)).to eq([])
  end

  it 'rejects a field of the wrong shape' do
    bodies = { credits: ['{}', '{"Credits":[1]}', '{"Credits":"abc"}'], validate_file_check: ['{"errors":[1]}'] }
    expect(wrong(->(name) { bodies.fetch(name, []) })).to eq([])
  end

  it 'still parses the documented shapes' do
    answer('[]')
    expect(Zerobounce.list_filters).to eq([])
    expect(Zerobounce.list_s3_files).to eq([])
    answer('{"success":true,"files":[]}')
    expect(Zerobounce.list_s3_files).to eq('success' => true, 'files' => [])
    answer('{"Credits":"7"}')
    expect(Zerobounce.credits).to eq(7)
    answer('{"Credits":"-1"}')
    expect(Zerobounce.credits).to eq(-1)
  end
end

# E7: a body nested deeper than the parser allows (200000 "[") is an API error
# with status 200 on every call, downloads and Warmup included: not a
# SystemStackError, a NestingError or a hang.
describe 'a deeply nested body on every call' do
  root = 'https://first.example'

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('depth-key', root)
  end

  it 'is an API error with status 200' do
    calls = TransportSweep::CALLS.to_a +
            TransportSweep::WARMUP_CALLS.map do |name, call|
              ["warmup.#{name}", -> { call.call(TransportSweep.warmup('depth-key', root)) }]
            end
    wrong = []
    ['[' * 200_000, ('[' * 100_000) + (']' * 100_000), "#{'{"a":' * 100_000}1#{'}' * 100_000}"].each do |body|
      WebMock.reset!
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
      calls.each do |name, call|
        call.call
        wrong << [name, body.size, 'accepted']
      rescue Zerobounce::ApiResponseError => e
        wrong << [name, body.size, e.status_code] unless e.status_code == 200
      rescue StandardError, SystemStackError => e
        wrong << [name, body.size, e.class.name]
      end
    end
    expect(wrong).to eq([])
  end
end

# S4: the redaction check decodes four layers (the SDK's own request encoding
# plus three echo layers), every decode step is needed, surrogate pairs are
# joined, and a NUL or %00 before the secret does not end the check.
describe 'the redaction decode check' do
  omitted = Zerobounce::ApiKey::CREDENTIAL_OMITTED_MESSAGE

  def lower_hex(text)
    text.b.bytes.map { |byte| format('%%%02x', byte) }.join
  end

  def three_times(text)
    3.times.reduce(text) { |form, _| ERB::Util.url_encode(form) }
  end

  it 'covers a key under four layers' do
    secret = %(probe"key/ZQXMARK01+23&ab c\\xyz)
    body = three_times("GET /v2/getcredits?api_key=#{CGI.escape(secret)} HTTP/1.1")
    expect(Zerobounce::ApiKey.redact(body, [secret])).to eq(omitted)
  end

  it 'omits a request URL echoed under three more encodings, on every call' do
    secret = %(probe"key/ZQXMARK01+23&ab c\\xyz)
    root = 'https://first.example'
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure(secret, root)
    leaks = []
    errors = 0
    stub_request(:any, %r{\Ahttps://first\.example/}).to_return do |request|
      { status: 400, body: three_times(request.uri.to_s), headers: { 'Content-Type' => 'text/plain' } }
    end
    TransportSweep::CALLS.each do |name, call|
      call.call
    rescue StandardError => e
      errors += 1
      views = EncodingFuzz.texts(e).flat_map { |text| Zerobounce::ApiKey.decoded_views(text, 4) }
      leaks << name if views.any? { |view| view.include?('ZQXMARK') }
    end
    expect(errors).to be > 40
    expect(leaks).to eq([])
  ensure
    Zerobounce.configuration = saved
  end

  it 'needs every decode step' do
    secret = 'zq x/ZQXMARK'
    u_escaped = secret.chars.map { |char| format('\\u%04x', char.ord) }.join
    bodies = {
      'lower-case %xx after invalid UTF-8' => "%ff%fe#{lower_hex(secret)}",
      '+ as space, then %xx' => "#{lower_hex('zq')}+#{lower_hex('x/ZQXMARK')}",
      'JSON \\u escapes' => u_escaped,
      '\\u escapes, URL-encoded' => lower_hex(u_escaped),
      'a literal + kept, %xx decoded' => "zq+x#{lower_hex('/ZQXMARK')}",
      'NUL first' => "\u0000#{u_escaped}",
      '%00 first' => "%00#{lower_hex(secret)}"
    }
    bodies.each do |label, body|
      secrets = label.start_with?('a literal +') ? ['zq+x/ZQXMARK'] : [secret]
      expect(Zerobounce::ApiKey.redact("rejected #{body}", secrets)).to eq(omitted), label
    end
  end

  it 'decodes every UTF-8 sequence length of a \\u escape' do
    { 1 => 'z', 2 => "\u{e9}", 3 => "\u{20ac}", 4 => "\u{1F600}" }.each do |length, char|
      expect(char.bytesize).to eq(length)
      secret = "zq#{char}ZQXMARK"
      # Every UTF-16 unit \u-escaped, ASCII too: a spelling no mask form covers.
      body = secret.encode('UTF-16BE').unpack('n*').map { |unit| format('\\u%04x', unit) }.join
      expect(Zerobounce::ApiKey.redact("rejected #{body}", [secret])).to eq(omitted), "#{length} bytes"
      expect(Zerobounce::ApiKey.redact("rejected #{lower_hex(body)}", [secret])).to eq(omitted), "#{length} bytes, %xx"
    end
  end

  it 'reads + as a space without %-decoding, as a step of its own' do
    expect(Zerobounce::ApiKey.redact('rejected zq+x%41ZQXMARK', ['zq x%41ZQXMARK'])).to eq(omitted)
  end

  it 'joins a \\u-escaped surrogate pair' do
    secret = "pw\u{1F600}ZQXMARK"
    once = JSON.generate(secret, ascii_only: true)[1..-2]
    body = once.chars.map { |char| format('\\u%04x', char.ord) }.join
    expect(Zerobounce::ApiKey.redact(body, [secret])).to eq(omitted)
  end
end

# E7: the fields the standard names. Credits must be an integer, sent as a JSON
# string or a JSON integer; a validate result and every validate_batch row carry address and
# status as strings (the greylist {"Message": "..."} answer is a result). The
# other fields of a Hash result pass through as sent.
describe 'field types on the typed fields' do
  root = 'https://first.example'

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('fields-key', root)
  end

  def answer(body)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  def expect_shape_error(body, &call)
    answer(body)
    expect(&call).to raise_error(Zerobounce::ApiResponseError, /unexpected shape/) { |e|
      expect(e.status_code).to eq(200), body
    }
  end

  it 'requires Credits to be an integer, as a JSON string or a JSON number' do
    ['{}', '{"Credits":null}', '{"Credits":true}', '{"Credits":false}', '{"Credits":1.5}', '{"Credits":5.0}',
     '{"Credits":1e3}', '{"Credits":"abc"}', '{"Credits":"5.0"}', '{"Credits":""}', '{"Credits":" 5"}',
     '{"Credits":"5\n"}', '{"Credits":"٥"}', '{"Credits":[1]}', '{"Credits":{"a":1}}'].each do |body|
      expect_shape_error(body) { Zerobounce.credits }
    end
    # The live API sends a JSON string; zerobounce.net's example a JSON number.
    { '{"Credits":"-1"}' => -1, '{"Credits":"2375323"}' => 2_375_323, '{"Credits":2375323}' => 2_375_323,
      '{"Credits":-1}' => -1, '{"Credits":0}' => 0 }.each do |body, credits|
      answer(body)
      expect(Zerobounce.credits).to eq(credits), body
    end
  end

  it 'requires a string address and status from validate, on GET and POST' do
    ['{}', '{"address":"a@b.c"}', '{"status":"valid"}', '{"address":null,"status":"valid"}',
     '{"address":"a@b.c","status":null}', '{"address":true,"status":"valid"}', '{"address":"a@b.c","status":5}',
     '{"address":"a@b.c","status":["valid"]}'].each do |body|
      expect_shape_error(body) { Zerobounce.validate('a@example.com') }
      expect_shape_error(body) { Zerobounce.validate('a@example.com', use_post: true) }
    end
  end

  it 'requires a string address and status in every validate_batch row' do
    ['{"email_batch":[{"status":"valid"}],"errors":[]}', '{"email_batch":[{"address":"a@b.c"}],"errors":[]}',
     '{"email_batch":[{"address":"a@b.c","status":null}],"errors":[]}',
     '{"email_batch":[{"address":"a@b.c","status":5}],"errors":[]}',
     '{"email_batch":[{"address":"a@b.c","status":"valid"},{}],"errors":[]}',
     '{"email_batch":["x"],"errors":[]}', '{"email_batch":[5],"errors":[]}', '{"email_batch":[null],"errors":[]}',
     '{"email_batch":[true],"errors":[]}', '{"email_batch":[1.5],"errors":[]}',
     '{"email_batch":[["a@b.c","valid"]],"errors":[]}'].each do |body|
      expect_shape_error(body) { Zerobounce.validate_batch(['a@example.com']) }
    end
  end

  # Every wrong JSON type at every nested path Ruby types (each batch row, and
  # its address and status), substituted into the documented batch answer.
  it 'rejects every wrong JSON type at every nested path of a validate_batch answer' do
    row = { 'address' => 'valid@example.com', 'status' => 'valid', 'sub_status' => '', 'free_email' => false }
    example = { 'email_batch' => [row, row.merge('address' => 'b@example.com')], 'errors' => [] }
    mutations = []
    not_objects = [5, 1.5, true, false, nil, 'x', [], ['x'], [row['address'], row['status']]]
    not_strings = [5, 1.5, true, false, nil, [], ['valid'], {}, { 'a' => 1 }]
    example['email_batch'].each_index do |index|
      not_objects.each do |wrong|
        mutations << ["email_batch[#{index}]", wrong, index, nil]
      end
      %w[address status].each do |field|
        not_strings.each do |wrong|
          mutations << ["email_batch[#{index}].#{field}", example['email_batch'][index].merge(field => wrong), index,
                        field]
        end
      end
    end
    answer(JSON.generate(example))
    expect(Zerobounce.validate_batch(['a@example.com'])['email_batch'].size).to eq(2)
    wrong = mutations.filter_map do |path, value, index, _field|
      rows = example['email_batch'].dup
      rows[index] = value
      body = JSON.generate(example.merge('email_batch' => rows))
      answer(body)
      begin
        Zerobounce.validate_batch(['a@example.com'])
        [path, body, 'accepted']
      rescue Zerobounce::ApiResponseError => e
        [path, body, e.status_code, e.message] unless e.status_code == 200 && e.message.include?('unexpected shape')
      rescue StandardError => e
        [path, body, e.class.name]
      end
    end
    expect(mutations.size).to be > 30
    expect(wrong).to eq([])
  end

  it 'still parses the documented examples and the greylist answer' do
    validate = '{"address":"flowerjill@aol.com","status":"valid","sub_status":"","free_email":true,' \
               '"did_you_mean":null,"account":"flowerjill","domain":"aol.com","domain_age_days":"9692",' \
               '"active_in_days":"180","smtp_provider":"yahoo","mx_found":"true",' \
               '"mx_record":"mx-aol.mail.gm0.yahoodns.net","firstname":"Jill","lastname":"Stein","gender":"female",' \
               '"country":"United States","region":"Florida","city":"West Palm Beach","zipcode":"33401",' \
               '"processed_at":"2017-04-01 02:48:02.592"}'
    answer(validate)
    expect(Zerobounce.validate('a@example.com')['status']).to eq('valid')
    answer('{"Message":"Greylist validation still in progress..."}')
    expect(Zerobounce.validate('a@example.com', use_post: true)['Message']).to start_with('Greylist')
    answer('{"address":"a@b.c","status":"brand_new"}')
    expect(Zerobounce.validate('a@example.com')['status']).to eq('brand_new')
    answer("{\"email_batch\":[#{validate}],\"errors\":[]}")
    expect(Zerobounce.validate_batch(['a@example.com'])['email_batch'].size).to eq(1)
    answer('{"email_batch":[],"errors":[{"error":"Invalid email","email_address":"x"}]}')
    expect(Zerobounce.validate_batch(['x'])['errors'].size).to eq(1)
  end
end

# E2: a dead-key body on a 200 ({"error"}, {"error_message"}, {"Error"}, no
# "success") is an ApiResponseError with status 200 on every call, the
# sendfile-family uploads and the downloads included: never a result.
describe 'a dead key on a 200 on every call' do
  root = 'https://first.example'
  uploads = %i[validate_file_send validate_file_send_stream scoring_file_send scoring_file_send_stream
               send_email_finder_file send_domain_search_file send_list_evaluator_file send_evaluated_file]

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('dead-key', root)
  end

  it 'names every sendfile-family upload' do
    expect(TransportSweep::CALLS.keys).to include(*uploads)
  end

  ['{"error":"Invalid API key or your account ran out of credits"}', '{"error_message":"Invalid API key"}',
   '{"Error":"Invalid API key or your account ran out of credits"}'].each do |body|
    it "raises with status 200 for #{body}" do
      WebMock.reset!
      stub_request(:any, %r{\Ahttps://first\.example/})
        .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
      wrong = []
      TransportSweep::CALLS.each do |name, call|
        call.call
        wrong << [name, 'accepted']
      rescue Zerobounce::ApiResponseError => e
        wrong << [name, e.status_code, e.message] unless e.status_code == 200 && e.message.include?('Invalid API key')
      rescue StandardError => e
        wrong << [name, e.class.name]
      end
      expect(wrong).to eq([])
    end
  end
end

# Example responses copied verbatim from zerobounce.net/docs, kept in
# spec/fixtures/zerobounce_net_examples.json. Success examples must parse; the
# documented error examples must be API errors with status 200.
describe 'the examples on zerobounce.net' do
  root = 'https://first.example'
  examples = JSON.parse(File.read(File.expand_path('fixtures/zerobounce_net_examples.json', __dir__)))

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('examples-key', root)
  end

  def answer(body)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  it 'parses every documented result' do
    expect(examples['results'].size).to be >= 9
    examples['results'].each do |entry|
      answer(entry['body'])
      expect(TransportSweep::CALLS.fetch(entry['call'].to_sym).call).not_to be_nil, entry['body']
    end
    answer('{"Credits":2375323}')
    expect(Zerobounce.credits).to eq(2_375_323)
  end

  it 'reports every documented error with status 200' do
    expect(examples['errors'].size).to be >= 10
    examples['errors'].each do |entry|
      answer(entry['body'])
      expect { TransportSweep::CALLS.fetch(entry['call'].to_sym).call }
        .to raise_error(Zerobounce::ApiResponseError) { |e| expect(e.status_code).to eq(200), entry['body'] }
    end
  end
end
# rubocop:enable Metrics/BlockLength, Metrics/ModuleLength

# rubocop:disable Metrics/BlockLength
# Round 16 (C, B, D, E, A). The documented shape of every typed call is written
# out here from zerobounce.net and the other SDKs, not read from the SDK, so a
# table the SDK gets wrong fails these tests. Field kinds: :string; :flag (a
# JSON boolean, or the "true"/"false" string the API also sends); :int; :number;
# :array; :text_or_array (a string, or an array of strings).
module DocumentedAnswers
  VALIDATE = {
    'address' => :string, 'status' => :string, 'sub_status' => :string, 'account' => :string,
    'domain' => :string, 'did_you_mean' => :string, 'domain_age_days' => :string, 'active_in_days' => :string,
    'active_first_seen' => :string, 'free_email' => :flag, 'mx_found' => :flag, 'mx_record' => :string,
    'smtp_provider' => :string, 'catchall_domain' => :flag, 'firstname' => :string, 'lastname' => :string,
    'gender' => :string, 'city' => :string, 'region' => :string, 'zipcode' => :string, 'country' => :string,
    'processed_at' => :string, 'domain_website_exists' => :string, 'domain_registrant_company_name' => :string,
    'message' => :string, 'Message' => :string
  }.freeze
  API_USAGE = %w[
    total status_valid status_invalid status_catch_all status_do_not_mail status_spamtrap
    status_unknown sub_status_toxic sub_status_disposable sub_status_role_based
    sub_status_possible_trap sub_status_global_suppression sub_status_timeout_exceeded
    sub_status_mail_server_temporary_error sub_status_mail_server_did_not_respond
    sub_status_greylisted sub_status_antispam_system sub_status_does_not_accept_mail
    sub_status_exception_occurred sub_status_failed_syntax_check sub_status_mailbox_not_found
    sub_status_unroutable_ip_address sub_status_possible_typo sub_status_no_dns_entries
    sub_status_role_based_catch_all sub_status_mailbox_quota_exceeded
    sub_status_forcible_disconnect sub_status_failed_smtp_connection sub_status_accept_all
    sub_status_mx_forward sub_status_alternate sub_status_allowed sub_status_blocked
    sub_status_gold sub_status_role_based_accept_all sub_status_leading_period_removed
    sub_status_alias_address
  ].to_h { |name| [name, :int] }
              .merge('start_date' => :string, 'end_date' => :string).freeze
  ACTIVITY = { 'found' => :flag, 'active_in_days' => :string, 'active_first_seen' => :string }.freeze
  SCORE = { 'email' => :string, 'score' => :int }.freeze
  FILE_STATUS = {
    'success' => :flag, 'message' => :text_or_array, 'file_id' => :string, 'file_name' => :string,
    'upload_date' => :string, 'file_status' => :string, 'file_phase_2_status' => :string,
    'complete_percentage' => :string, 'error_reason' => :string, 'return_url' => :string
  }.freeze
  SEND_FILE = {
    'success' => :flag, 'message' => :text_or_array, 'file_name' => :string, 'file_id' => :string
  }.freeze
  LIST_EVALUATOR = {
    'file_id' => :string, 'status' => :string, 'progress' => :number, 'invalid_percentage' => :number,
    'catch_all_percentage' => :number, 'activity_data_percentage' => :number, 'abuse' => :flag,
    'do_not_mail' => :flag, 'spam_trap' => :flag, 'total_risky_percentage' => :number, 'error_message' => :string
  }.freeze
  GUESS = {
    'email' => :string, 'domain' => :string, 'company_name' => :string, 'format' => :string,
    'status' => :string, 'sub_status' => :string, 'confidence' => :string, 'email_confidence' => :string,
    'failure_reason' => :string, 'did_you_mean' => :string, 'other_domain_formats' => :array
  }.freeze
  DOMAIN_FORMAT = { 'format' => :string, 'confidence' => :string }.freeze
  BATCH_ERROR = { 'error' => :string, 'email_address' => :string }.freeze
  BATCH = { 'email_batch' => :array, 'errors' => :array }.freeze

  # Every JSON type a documented field of each kind does not allow.
  WRONG = {
    string: [5, 5.5, true, [], {}],
    flag: [5, 5.5, [], {}],
    int: ['5', 5.5, true, [], {}],
    number: ['5', true, [], {}],
    array: [5, 'x', true, {}],
    text_or_array: [5, 5.5, true, {}, [5]]
  }.freeze
  VALID = { string: 'x', flag: true, int: 5, number: 5.5, array: [], text_or_array: 'x' }.freeze

  FILE = 'spec/fixtures/priority3_finder.csv'
  ONE = ['a@example.com'].freeze

  # name => [call, fields, required fields, nested arrays (name => [fields, required])]
  CALLS = {
    'validate' => [-> { Zerobounce.validate('a@example.com') }, VALIDATE, %w[address status], {}],
    'validate (POST)' => [-> { Zerobounce.validate('a@example.com', use_post: true) }, VALIDATE,
                          %w[address status], {}],
    'validate_batch' => [-> { Zerobounce.validate_batch(ONE) }, BATCH, [],
                         { 'email_batch' => [VALIDATE, %w[address status]], 'errors' => [BATCH_ERROR, []] }],
    'api_usage' => [-> { Zerobounce.api_usage(Date.new(2024, 1, 1), Date.new(2024, 1, 2)) }, API_USAGE, [], {}],
    'activity' => [-> { Zerobounce.activity('a@example.com') }, ACTIVITY, [], {}],
    'score_email' => [-> { Zerobounce.score_email('a@example.com') }, SCORE, [], {}],
    'score_email (POST)' => [-> { Zerobounce.score_email('a@example.com', use_post: true) }, SCORE, [], {}],
    'validate_file_check' => [-> { Zerobounce.validate_file_check('f1') }, FILE_STATUS, [], {}],
    'scoring_file_check' => [-> { Zerobounce.scoring_file_check('f1') }, FILE_STATUS, [], {}],
    'email_finder_file_status' => [-> { Zerobounce.email_finder_file_status('f1') }, FILE_STATUS, [], {}],
    'domain_search_file_status' => [-> { Zerobounce.domain_search_file_status('f1') }, FILE_STATUS, [], {}],
    'validate_file_send' => [-> { Zerobounce.validate_file_send(FILE) }, SEND_FILE, [], {}],
    'scoring_file_send' => [-> { Zerobounce.scoring_file_send(FILE) }, SEND_FILE, [], {}],
    'send_email_finder_file' => [-> { Zerobounce.send_email_finder_file(FILE, domain_column: 1, first_name_column: 2) },
                                 SEND_FILE, [], {}],
    'send_domain_search_file' => [-> { Zerobounce.send_domain_search_file(FILE, domain_column: 1) }, SEND_FILE, [], {}],
    'send_evaluated_file' => [-> { Zerobounce.send_evaluated_file('f1') }, SEND_FILE, [], {}],
    'validate_file_delete' => [-> { Zerobounce.validate_file_delete('f1') }, SEND_FILE, [], {}],
    'scoring_file_delete' => [-> { Zerobounce.scoring_file_delete('f1') }, SEND_FILE, [], {}],
    'email_finder_file_delete' => [-> { Zerobounce.email_finder_file_delete('f1') }, SEND_FILE, [], {}],
    'domain_search_file_delete' => [-> { Zerobounce.domain_search_file_delete('f1') }, SEND_FILE, [], {}],
    'guessformat' => [-> { Zerobounce.guessformat('example.com') }, GUESS, [],
                      { 'other_domain_formats' => [DOMAIN_FORMAT, []] }],
    'find_email' => [-> { Zerobounce.find_email('Ann', domain: 'example.com') }, GUESS, [],
                     { 'other_domain_formats' => [DOMAIN_FORMAT, []] }],
    'find_domain' => [-> { Zerobounce.find_domain(domain: 'example.com') }, GUESS, [],
                      { 'other_domain_formats' => [DOMAIN_FORMAT, []] }],
    'send_list_evaluator_file' => [-> { Zerobounce.send_list_evaluator_file(FILE, email_address_column: 1) },
                                   LIST_EVALUATOR, [], {}],
    'get_list_evaluator_result' => [-> { Zerobounce.get_list_evaluator_result('f1') }, LIST_EVALUATOR, [], {}]
  }.freeze

  # A documented answer with every field valid; +overrides+ replace some of them. The
  # error text of a body with no "success" is "" (the documented empty value).
  def self.body(fields, overrides = {})
    fields.to_h { |name, kind| [name, name == 'error_message' ? '' : VALID.fetch(kind)] }.merge(overrides)
  end
end

describe 'documented field types on every typed call' do
  root = 'https://first.example'

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('types-key', root)
  end

  def answer(body)
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  # Runs the call on +body+: :ok for a result, or the error's status.
  def outcome(call, body)
    answer(JSON.generate(body))
    call.call
    :ok
  rescue Zerobounce::ApiResponseError => e
    e.message.include?('unexpected shape') ? e.status_code : [e.status_code, e.message]
  rescue StandardError => e
    e.class.name
  end

  it 'accepts every documented field with a value of its type' do
    DocumentedAnswers::CALLS.each do |name, (call, fields, _required, _nested)|
      answer(JSON.generate(DocumentedAnswers.body(fields)))
      expect(call.call).to be_a(Hash), name
    end
  end

  it 'rejects every wrong JSON type in every documented field, with status 200' do
    wrong = []
    count = 0
    DocumentedAnswers::CALLS.each do |name, (call, fields, _required, _nested)|
      fields.each do |field, kind|
        DocumentedAnswers::WRONG.fetch(kind).each do |value|
          count += 1
          result = outcome(call, DocumentedAnswers.body(fields, field => value))
          wrong << [name, field, value, result] unless result == 200
        end
      end
    end
    expect(count).to be > 300
    expect(wrong).to eq([])
  end

  it 'reads null in an optional field as absent, and rejects null in a required one' do
    wrong = []
    DocumentedAnswers::CALLS.each do |name, (call, fields, required, _nested)|
      fields.each_key do |field|
        result = outcome(call, DocumentedAnswers.body(fields, field => nil))
        if required.include?(field)
          wrong << [name, field, result] unless result == 200
        else
          wrong << [name, field, result] unless result == :ok
        end
      end
    end
    expect(wrong).to eq([])
  end

  it 'checks every field of every item of a documented array, on every call that has one' do
    wrong = []
    count = 0
    DocumentedAnswers::CALLS.each do |name, (call, fields, _required, nested)|
      nested.each do |array, (item_fields, _item_required)|
        item_fields.each do |field, kind|
          DocumentedAnswers::WRONG.fetch(kind).each do |value|
            count += 1
            item = DocumentedAnswers.body(item_fields, field => value)
            result = outcome(call, DocumentedAnswers.body(fields, array => [item]))
            wrong << [name, array, field, value, result] unless result == 200
          end
        end
      end
    end
    expect(count).to be > 60
    expect(wrong).to eq([])
  end

  it 'keeps a message list as sent (a Hash result passes every field through)' do
    answer('{"success":true,"message":["File Accepted","Queued"],"file_id":"f1","file_name":"a.csv"}')
    expect(Zerobounce.validate_file_send(TransportSweep::FILE)['message']).to eq(['File Accepted', 'Queued'])
  end
end

# Round 16 (D, E, A). An HTML page served as text/csv is an error on every
# download (the sniff reads the body, not only the content type); return_url is
# sent only when given; a "success":"false" string is a failure; the documented
# batch and API usage answers parse; the key is not in a client's dump.
describe 'round 16 guards: HTML downloads, return_url, string false, examples, key dumps' do
  root = 'https://first.example'
  html = '<!DOCTYPE html><html><head><title>Access denied</title></head><body>Denied</body></html>'

  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    allow(Zerobounce).to receive(:warn)
    TransportSweep.configure('guard-key-123', root)
  end

  def answer(body, content_type: 'application/json')
    WebMock.reset!
    stub_request(:any, %r{\Ahttps://first\.example/})
      .to_return(status: 200, body: body, headers: { 'Content-Type' => content_type })
  end

  describe 'an HTML page under a CSV content type' do
    it 'is an error on every getfile call and on the Warmup downloads' do
      calls = {
        validate_file_get: -> { Zerobounce.validate_file_get('f1') },
        scoring_file_get: -> { Zerobounce.scoring_file_get('f1') },
        email_finder_file_get: -> { Zerobounce.email_finder_file_get('f1') },
        domain_search_file_get: -> { Zerobounce.domain_search_file_get('f1') }
      }
      calls.each do |name, call|
        answer(html, content_type: 'text/csv')
        expect(&call).to raise_error(Zerobounce::ApiResponseError), name.to_s
      end
      %i[download_seeds download_statistics].each do |name|
        answer(html, content_type: 'text/csv')
        warmup = TransportSweep.warmup('guard-key-123', root)
        expect { TransportSweep::WARMUP_CALLS.fetch(name).call(warmup) }
          .to raise_error(Zerobounce::ApiResponseError), name.to_s
      end
    end

    it 'is an error with an HTML body under a text/html type as well' do
      answer(html, content_type: 'text/html')
      expect { Zerobounce.validate_file_get('f1') }.to raise_error(Zerobounce::ApiResponseError)
    end
  end

  describe 'a message-only finder body' do
    it 'is an error with status 200 even when the message is null, and a message beside a result is not' do
      answer('{"message":null}')
      expect { Zerobounce.find_domain(domain: 'example.com') }.to raise_error(Zerobounce::ApiResponseError,
                                                                              'Request failed') { |e|
                                                                    expect(e.status_code).to eq(200)
                                                                  }
      answer('{"domain":"example.com","format":"first.last","message":null}')
      expect(Zerobounce.find_domain(domain: 'example.com')['format']).to eq('first.last')
    end
  end

  describe 'return_url' do
    it 'is not sent unless the caller gives one' do
      answer('{"success":true,"message":"File Accepted","file_id":"f1","file_name":"f.csv"}')
      Zerobounce.validate_file_send(TransportSweep::FILE)
      Zerobounce.scoring_file_send(TransportSweep::FILE)
      expect(a_request(:post, %r{/sendfile|/scoring/sendfile}).with { |req| req.body.to_s.include?('return_url') })
        .not_to have_been_made
    end

    it 'is sent when given' do
      answer('{"success":true,"message":"File Accepted","file_id":"f1","file_name":"f.csv"}')
      Zerobounce.validate_file_send(TransportSweep::FILE, return_url: TransportSweep::DONE)
      expect(a_request(:post, %r{/sendfile}).with { |req| req.body.to_s.include?(TransportSweep::DONE) })
        .to have_been_made
    end
  end

  describe 'a "success":"false" string' do
    it 'is a failure with status 200 on every bulk status, send and delete call' do
      body = '{"success":"false","message":"File cannot be found."}'
      [-> { Zerobounce.validate_file_check('f1') }, -> { Zerobounce.validate_file_delete('f1') },
       -> { Zerobounce.scoring_file_check('f1') }, -> { Zerobounce.email_finder_file_status('f1') },
       -> { Zerobounce.domain_search_file_delete('f1') }, -> { Zerobounce.validate_file_send(TransportSweep::FILE) }]
        .each do |call|
        answer(body)
        expect(&call).to raise_error(Zerobounce::ApiResponseError, 'File cannot be found.') { |e|
          expect(e.status_code).to eq(200)
        }
      end
    end
  end

  describe 'the documented answers (verbatim from zerobounce.net)' do
    it 'parses the batch-validate success answer with three rows' do
      answer(<<~JSON)
        {
              "email_batch": [
                  {
                      "address": "john.doe@zerobounce.net",
                      "status": "valid",
                      "sub_status": "",
                      "free_email": false,
                      "catchall_domain": true,
                      "did_you_mean": null,
                      "account": "johndoe",
                      "domain": "zerobounce.net",
                      "domain_age_days": "3431",
                      "active_in_days": "30",
                      "active_first_seen": "2026-02-25",
                      "smtp_provider": "g-suite",
                      "mx_found": "true",
                      "mx_record": "aspmx.l.google.com",
                      "firstname": "dan",
                      "lastname": "cotet",
                      "gender": "male",
                      "country": null,
                      "region": null,
                      "city": null,
                      "zipcode": null,
                      "processed_at": "2026-06-18 07:05:00.033"
                  },
                  {
                      "address": "invalid@example.com",
                      "status": "invalid",
                      "sub_status": "mailbox_not_found",
                      "free_email": false,
                      "did_you_mean": null,
                      "account": null,
                      "domain": null,
                      "domain_age_days": "9692",
                      "active_in_days": "365",
                      "active_first_seen": "2026-02-25",
                      "smtp_provider": "example",
                      "mx_found": "true",
                      "mx_record": "mx.example.com",
                      "catchall_domain": false,
                      "firstname": "zero",
                      "lastname": "bounce",
                      "gender": "male",
                      "country": null,
                      "region": null,
                      "city": null,
                      "zipcode": null,
                      "processed_at": "2020-09-17 17:43:11.830"
                  },
                  {
                      "address": "disposable@example.com",
                      "status": "do_not_mail",
                      "sub_status": "disposable",
                      "free_email": false,
                      "did_you_mean": null,
                      "account": null,
                      "domain": null,
                      "domain_age_days": "9692",
                      "active_in_days": "365",
                      "active_first_seen": "2026-02-25",
                      "smtp_provider": "example",
                      "mx_found": "true",
                      "mx_record": "mx.example.com",
                      "catchall_domain": false,
                      "firstname": "zero",
                      "lastname": "bounce",
                      "gender": "male",
                      "country": null,
                      "region": null,
                      "city": null,
                      "zipcode": null,
                      "processed_at": "2020-09-17 17:43:11.830"
                  }
              ],
              "errors": []
          }
      JSON
      expect(Zerobounce.validate_batch(['john.doe@zerobounce.net'])['email_batch'].map { |row| row['status'] })
        .to eq(%w[valid invalid do_not_mail])
    end

    it 'parses the get-api-usage success answer' do
      answer(<<~JSON)
        {
              "total": 120,
              "status_valid": 17,
              "status_invalid": 69,
              "status_catch_all": 9,
              "status_do_not_mail": 16,
              "status_spamtrap": 0,
              "status_unknown": 6,
              "sub_status_toxic": 0,
              "sub_status_disposable": 1,
              "sub_status_role_based": 1,
              "sub_status_possible_trap": 0,
              "sub_status_global_suppression": 14,
              "sub_status_timeout_exceeded": 0,
              "sub_status_mail_server_temporary_error": 0,
              "sub_status_mail_server_did_not_respond": 0,
              "sub_status_greylisted": 6,
              "sub_status_antispam_system": 0,
              "sub_status_does_not_accept_mail": 27,
              "sub_status_exception_occurred": 0,
              "sub_status_failed_syntax_check": 20,
              "sub_status_mailbox_not_found": 12,
              "sub_status_unroutable_ip_address": 0,
              "sub_status_possible_typo": 0,
              "sub_status_no_dns_entries": 10,
              "sub_status_role_based_catch_all": 0,
              "sub_status_mailbox_quota_exceeded": 0,
              "sub_status_forcible_disconnect": 0,
              "sub_status_failed_smtp_connection": 0,
              "sub_status_leading_period_removed": 0,
              "sub_status_alias_address": 2,
              "sub_status_mx_forward": 0,
              "sub_status_alternate": 0,
              "sub_status_blocked": 0,
              "sub_status_allowed": 0,
              "start_date": "1/1/2023",
              "end_date": "1/30/2024"
            }
      JSON
      usage = Zerobounce.api_usage(Date.new(2023, 1, 1), Date.new(2024, 1, 30))
      expect(usage['total']).to eq(120)
      expect(usage['sub_status_alias_address']).to eq(2)
    end
  end

  describe 'the API key in a client dump' do
    it 'is not in the instance variables or the inspect of a Client or a Warmup client' do
      client = Zerobounce::Client.new('dump-key-123')
      warmup = Zerobounce::Warmup.new('dump-key-123')
      [client, warmup].each do |object|
        values = object.instance_variables.map { |name| object.instance_variable_get(name) }
        expect(values.map(&:inspect).join).not_to include('dump-key-123'), object.class.name
        expect(object.inspect).not_to include('dump-key-123'), object.class.name
        expect(object.to_s).not_to include('dump-key-123'), object.class.name
        expect(PP.pp(object, +'')).not_to include('dump-key-123'), object.class.name
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
