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
        # A body that does not parse is the only API error a 2xx without an
        # error field gives; a result of the wrong shape is a different error.
        wrong << [name, body, e.message] if e.status_code == 200
      rescue StandardError
        nil
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
# rubocop:enable Metrics/BlockLength, Metrics/ModuleLength
