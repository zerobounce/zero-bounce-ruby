# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# rubocop:disable Metrics/BlockLength
# Every boolean parameter of every public method is parsed strictly: 'false'
# is never sent as true and anything that is not a boolean raises before a
# request. The parameters are found from the methods' signatures, so a new
# boolean parameter (or a new method taking one) fails the completeness
# checks until it is added to the sweep.
module StrictBooleanSweep
  FILE = 'spec/fixtures/priority3_finder.csv'
  DONE = 'https://example.com/d'

  # Parameter names that take a boolean.
  BOOLEAN_NAMES = %w[activity_data verify_plus domain_info greylist_processing has_header_row allow_phase_2
                     remove_duplicate remove_duplicates ignore_conflict auto_enable].freeze

  # Client-side switches that choose how a request is sent, not API fields.
  CLIENT_SWITCHES = %w[use_post].freeze

  # Every other parameter name of the public methods.
  OTHER_NAMES = %w[api_key body bucket c_from callback_url click_pct company_name dkim_selector domain
                   domain_column email email_address_column emails end_date engagement_rule_id export_bucket
                   export_path file_id file_name filepath first_name first_name_column from_address
                   full_name_column gender_column important_pct io ip_address ip_address_column ip_addresses last_name
                   last_name_column limit middle_name middle_name_column name new_from_address offset
                   old_from_address onboarding_model options opts password port reply_pct return_url rule
                   rule_id search search_from server start_date status_id target test_id timeout username value
                   webhook_url].freeze

  # The booleans a method takes through **options, which its signature does
  # not name. Every method with a ** parameter is listed, with [] when none.
  KEYREST_BOOLEANS = {
    validate_file_send_stream: %w[has_header_row remove_duplicate allow_phase_2],
    scoring_file_send_stream: %w[has_header_row remove_duplicate],
    validate_s3_file: %w[remove_duplicates],
    score_s3_file: %w[remove_duplicates],
    email_finder_s3_file: %w[remove_duplicates],
    domain_search_s3_file: %w[remove_duplicates],
    validate_sftp_file: %w[remove_duplicates],
    score_sftp_file: %w[remove_duplicates],
    email_finder_sftp_file: %w[remove_duplicates],
    domain_search_sftp_file: %w[remove_duplicates],
    create_inbox_placement_test: [],
    list_inbox_placement_tests: [],
    validate_file_get: [],
    scoring_file_get: [],
    'Warmup#add_sending_account': %w[ignore_conflict]
  }.freeze

  def self.csv_io
    StringIO.new("email\na@example.com\n")
  end

  # An S3/SFTP job, whose has_header_row is positional.
  def self.positional(method)
    lambda { |o|
      Zerobounce.public_send(method, 'f.csv', o.fetch(:has_header_row, true), return_url: DONE,
                                                                              **o.except(:has_header_row))
    }
  end

  # Each method with a boolean parameter, called with +o+ (the parameter
  # under test) merged into otherwise valid arguments.
  CALLS = {
    validate: ->(o) { Zerobounce.validate('a@example.com', **o) },
    validate_batch: ->(o) { Zerobounce.validate_batch(['a@example.com'], **o) },
    validate_file_send: ->(o) { Zerobounce.validate_file_send(FILE, **o) },
    validate_file_send_stream: ->(o) { Zerobounce.validate_file_send_stream(csv_io, 'f.csv', **o) },
    scoring_file_send: ->(o) { Zerobounce.scoring_file_send(FILE, **o) },
    scoring_file_send_stream: ->(o) { Zerobounce.scoring_file_send_stream(csv_io, 'f.csv', **o) },
    send_email_finder_file: lambda { |o|
      Zerobounce.send_email_finder_file(FILE, domain_column: 1, first_name_column: 2, **o)
    },
    send_domain_search_file: ->(o) { Zerobounce.send_domain_search_file(FILE, domain_column: 1, **o) },
    validate_s3_file: ->(o) { Zerobounce.validate_s3_file(file_name: 'f.csv', return_url: DONE, **o) },
    score_s3_file: ->(o) { Zerobounce.score_s3_file(file_name: 'f.csv', return_url: DONE, **o) },
    email_finder_s3_file: positional(:email_finder_s3_file),
    domain_search_s3_file: positional(:domain_search_s3_file),
    validate_sftp_file: positional(:validate_sftp_file),
    score_sftp_file: positional(:score_sftp_file),
    email_finder_sftp_file: positional(:email_finder_sftp_file),
    domain_search_sftp_file: positional(:domain_search_sftp_file),
    'Warmup#add_sending_account': lambda { |o|
      Zerobounce::Warmup.new('warmup-key').add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 0, **o)
    },
    'Warmup#update_sending_account': lambda { |o|
      Zerobounce::Warmup.new('warmup-key').update_sending_account('a@b.com', 1, 4, o.fetch(:auto_enable))
    }
  }.freeze

  # [method, parameter names] for every public method of the client and the
  # Warmup client.
  def self.public_methods_with_parameters
    client = Zerobounce.singleton_methods.map { |m| [m, Zerobounce.method(m).parameters] }
    warmup = Zerobounce::Warmup.public_instance_methods(false).map do |m|
      [:"Warmup##{m}", Zerobounce::Warmup.instance_method(m).parameters]
    end
    client + warmup
  end

  # The boolean parameters each public method takes, from its signature and
  # KEYREST_BOOLEANS.
  def self.booleans_by_method
    found = public_methods_with_parameters.to_h do |method, parameters|
      named = parameters.map { |_, name| name.to_s } & BOOLEAN_NAMES
      [method, (named + KEYREST_BOOLEANS.fetch(method, [])).uniq]
    end
    found.reject { |_, names| names.empty? }
  end

  # What a request sent for +name+: the query, a JSON body member, or a
  # multipart or form field, as a string ('true'/'false'); nil when not sent.
  def self.sent_value(request, name)
    query = URI.decode_www_form(request.uri.query.to_s).to_h
    return query[name] if query.key?(name)

    body_value(request.body.to_s, name)
  end

  def self.body_value(body, name)
    if body.start_with?('{')
      json = JSON.parse(body)
      return json.key?(name) ? json[name].to_s : nil
    end
    multipart = body.match(/name="#{Regexp.escape(name)}"\r\n(?:[^\r\n]+\r\n)*\r\n([^\r\n]*)/)
    multipart ? multipart[1] : URI.decode_www_form(body).to_h[name]
  rescue ArgumentError, JSON::ParserError
    nil
  end
end

describe 'Strict boolean parameters' do
  around do |example|
    saved = Zerobounce.configuration
    Zerobounce.configuration = Zerobounce::Configuration.new
    Zerobounce.configure { |c| c.apikey = 'bool-key' }
    example.run
  ensure
    Zerobounce.configuration = saved
  end

  before do
    stub_request(:any, /.*/)
      .to_return(status: 200, body: '{"success":true}', headers: { 'Content-Type' => 'application/json' })
  end

  def last_request
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
  end

  it 'classifies every parameter name of every public method' do
    names = StrictBooleanSweep.public_methods_with_parameters.flat_map { |_, ps| ps.map { |_, n| n.to_s } }
    known = StrictBooleanSweep::BOOLEAN_NAMES + StrictBooleanSweep::CLIENT_SWITCHES + StrictBooleanSweep::OTHER_NAMES
    expect(names.uniq.reject(&:empty?) - known).to eq([])
  end

  it 'lists the booleans of every method that takes **options' do
    with_keyrest = StrictBooleanSweep.public_methods_with_parameters
                                     .select { |_, ps| ps.any? { |type, _| type == :keyrest } }.map(&:first)
    expect(with_keyrest.sort - StrictBooleanSweep::KEYREST_BOOLEANS.keys).to eq([])
  end

  it 'knows every name the library parses as a strict boolean' do
    source = Dir['lib/**/*.rb'].map { |f| File.read(f) }.join("\n")
    parsed = source.scan(/(?:StrictBool\.parse|__strict_bool__|__wire_bool__)\([^,]+,\s*'(\w+)'\)/).flatten.uniq
    expect(parsed).not_to be_empty
    # weekdays_only sits inside add_sending_account's managed_sending Hash and
    # has its own spec in warmup_spec.rb.
    expect(parsed - StrictBooleanSweep::BOOLEAN_NAMES - %w[weekdays_only]).to eq([])
  end

  it 'sweeps every method that takes a boolean' do
    expect(StrictBooleanSweep.booleans_by_method.keys.sort).to eq(StrictBooleanSweep::CALLS.keys.sort)
  end

  StrictBooleanSweep::CALLS.each do |method, call|
    describe method.to_s do
      it "rejects 'junk' and never sends 'false' as true, for each boolean" do
        names = StrictBooleanSweep.booleans_by_method.fetch(method)
        names.each do |name|
          WebMock.reset_executed_requests!
          expect { call.call(name.to_sym => 'junk') }
            .to raise_error(ArgumentError, /#{name}/), "#{method} took #{name}: 'junk'"
          expect(a_request(:any, /.*/)).not_to have_been_made, "#{method} sent #{name}: 'junk'"

          WebMock.reset_executed_requests!
          begin
            call.call(name.to_sym => 'false')
          rescue ArgumentError => e
            # A parameter that takes only true/false may reject the string.
            expect(e.message).to match(/#{name}/)
            next
          end
          sent = StrictBooleanSweep.sent_value(last_request, name)
          expect(sent).to eq('false'), "#{method} sent #{name}: 'false' as #{sent.inspect}"
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
