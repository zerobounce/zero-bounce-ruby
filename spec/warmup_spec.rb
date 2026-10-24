# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

# Offline specs for the Warmup API client. Every request is stubbed with
# WebMock; nothing here reaches the live API, and the assertions are on what
# actually went on the wire.
describe Zerobounce::Warmup do
  let(:api_key) { 'warmup-key' }
  let(:root) { 'https://warmup-api.zerobounce.net/api/v1/warmup' }
  let(:warmup) { described_class.new(api_key) }

  def last_request
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
  end

  def last_query
    URI.decode_www_form(last_request.uri.query.to_s).to_h
  end

  def last_json
    JSON.parse(last_request.body.to_s)
  end

  def request_count
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.length
  end

  def stub_ok(body = '{"ok":true}', status: 200, content_type: 'application/json')
    stub_request(:any, %r{\Ahttps://warmup-api\.zerobounce\.net/})
      .to_return(status: status, body: body, headers: { 'Content-Type' => content_type })
  end

  # -- construction -------------------------------------------------------

  describe 'construction' do
    it 'sends the key in the API-Key header, never in the query string' do
      stub_ok
      warmup.seed_count
      expect(last_request.uri.path).to eq('/api/v1/warmup/seed-count')
      expect(last_request.headers['Api-Key']).to eq(api_key)
      expect(last_request.uri.query).to be_nil
    end

    it 'rejects a key that is empty or padded' do
      expect { described_class.new('') }.to raise_error(ArgumentError, /api_key/)
      [' key ', "key\n", "key\tx", "key\u0000"].each do |bad|
        expect { described_class.new(bad) }.to raise_error(ArgumentError, /whitespace/)
      end
    end

    it 'rejects a plain http base URL' do
      expect do
        described_class.new(api_key, 'http://warmup-api.zerobounce.net')
      end.to raise_error(ArgumentError, /https/)
    end

    it 'uses a custom https base URL' do
      stub_request(:any, %r{\Ahttps://warmup\.example\.com/})
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
      described_class.new(api_key, 'https://warmup.example.com/').seeds
      expect(last_request.uri.path).to eq('/api/v1/warmup/seeds')
    end
  end

  # -- paths and verbs ----------------------------------------------------

  describe 'paths and verbs' do
    before { stub_ok }

    it 'uses the documented path and verb for every endpoint' do
      {
        -> { warmup.list_sending_accounts } => [:get, '/sending-accounts'],
        -> { warmup.get_sending_account('a@b.com') } => [:get, '/sending-account'],
        -> { warmup.list_from_addresses } => [:get, '/from-addresses'],
        -> { warmup.engagement_rules } => [:get, '/engagement-rules'],
        -> { warmup.custom_engagement('a@b.com') } => [:get, '/custom-engagement/a@b.com'],
        -> { warmup.seeds } => [:get, '/seeds'],
        -> { warmup.seed_count } => [:get, '/seed-count'],
        -> { warmup.progress_today } => [:get, '/progress-today'],
        -> { warmup.sent_today } => [:get, '/sent-today'],
        -> { warmup.emails_per_day } => [:get, '/emails-per-day'],
        -> { warmup.statistics('a@b.com') } => [:get, '/statistics'],
        -> { warmup.statistics_detailed('a@b.com') } => [:get, '/statistics-detailed'],
        -> { warmup.from_address_statistics('a@b.com') } => [:get, '/from-address-statistics'],
        -> { warmup.check_domain_dmarc('a@b.com') } => [:get, '/check-domain-dmarc'],
        -> { warmup.add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 0) } =>
          [:post, '/sending-accounts'],
        -> { warmup.update_sending_account('a@b.com', 1, 4, true) } => [:put, '/sending-accounts'],
        -> { warmup.delete_sending_account('a@b.com') } => [:delete, '/sending-accounts'],
        -> { warmup.change_from_address('a@b.com', 'c@d.com') } => [:put, '/smtp-credentials'],
        -> { warmup.set_engagement_rule('a@b.com', 2) } => [:put, '/engagement-rule'],
        -> { warmup.create_custom_engagement('a@b.com', 10, 10, 5) } => [:post, '/custom-engagement'],
        -> { warmup.update_custom_engagement('a@b.com', 10, 10, 5) } => [:put, '/custom-engagement'],
        -> { warmup.delete_custom_engagement('a@b.com', 1) } => [:delete, '/custom-engagement'],
        -> { warmup.test_smtp_configuration('a@b.com', 'u', 'p', 'smtp.example.com', 587) } =>
          [:post, '/test-smtp-configuration']
      }.each do |call, (method, path)|
        call.call
        expect(last_request.method).to eq(method), "#{path} used #{last_request.method}"
        expect(last_request.uri.path).to eq("/api/v1/warmup#{path}")
      end
    end

    it 'encodes the custom-engagement id as one path segment' do
      warmup.custom_engagement('a b/c')
      # The slash stays encoded, so it cannot split the segment.
      expect(last_request.uri.path).to eq('/api/v1/warmup/custom-engagement/a%20b%2Fc')
    end

    it 'sends both dates on statistics-per-day' do
      warmup.statistics_per_day('a@b.com', Date.new(2026, 1, 2), '2026-01-09')
      expect(last_query).to include('start_date' => '2026-01-02', 'end_date' => '2026-01-09')
    end
  end

  # -- argument validation ------------------------------------------------

  describe 'argument validation' do
    before { stub_ok }

    it 'checks required arguments before any request' do
      [
        -> { warmup.get_sending_account('') },
        -> { warmup.delete_sending_account(' ') },
        -> { warmup.change_from_address('', 'b@c.com') },
        -> { warmup.change_from_address('a@b.com', '') },
        -> { warmup.set_engagement_rule('', 1) },
        -> { warmup.statistics('') },
        -> { warmup.download_statistics('') },
        -> { warmup.check_domain_dmarc('') }
      ].each { |call| expect { call.call }.to raise_error(ArgumentError) }
      expect(request_count).to eq(0)
    end

    it 'range-checks engagement rule ids' do
      [-1, 5, '2'].each do |bad|
        expect { warmup.set_engagement_rule('a@b.com', bad) }.to raise_error(ArgumentError, /rule_id/)
      end
      expect(request_count).to eq(0)

      (0..4).each do |good|
        warmup.set_engagement_rule('a@b.com', good)
        expect(last_json['rule_id']).to eq(good)
      end
    end

    it 'range-checks the custom engagement percentages' do
      [
        [4, 10, 5],    # reply_pct below 5
        [46, 10, 5],   # reply_pct above 45
        [10, 4, 5],    # important_pct below 5
        [10, 41, 5],   # important_pct above 40
        [10, 10, 71],  # click_pct above 70
        [10, 10, 18]   # click_pct above important_pct x 1.75
      ].each do |reply, important, click|
        expect do
          warmup.create_custom_engagement('a@b.com', reply, important, click)
        end.to raise_error(ArgumentError)
      end
      expect(request_count).to eq(0)

      warmup.create_custom_engagement('a@b.com', 20, 20, 35)
      expect(last_json).to eq(
        'c_from' => 'a@b.com', 'reply_pct' => 20, 'important_pct' => 20, 'click_pct' => 35
      )
    end

    it 'only falls back to a standard rule when deleting a custom one' do
      expect do
        warmup.delete_custom_engagement('a@b.com', 0)
      end.to raise_error(ArgumentError, /engagement_rule_id/)
      expect(request_count).to eq(0)

      warmup.delete_custom_engagement('a@b.com', 3)
      expect(last_json['engagement_rule_id']).to eq(3)
    end

    it 'range-checks update_sending_account and its flag' do
      expect { warmup.update_sending_account('a@b.com', 5, 4, true) }.to raise_error(ArgumentError)
      expect { warmup.update_sending_account('a@b.com', 1, 9, true) }.to raise_error(ArgumentError)
      expect { warmup.update_sending_account('a@b.com', 1, 4, 'yes') }.to raise_error(ArgumentError)
      expect(request_count).to eq(0)

      warmup.update_sending_account('a@b.com', 1, 5, false)
      expect(last_json).to eq(
        'team_id' => 1, 'from_address' => 'a@b.com', 'engagement_rule_id' => 1,
        'status_id' => 5, 'auto_enable' => false
      )
    end

    it 'checks the onboarding model' do
      expect do
        warmup.add_sending_account('a@b.com', 'managed', engagement_rule_id: 0)
      end.to raise_error(ArgumentError, /self_managed/)

      # self_managed needs its engagement rule and takes no ZB-managed fields.
      expect { warmup.add_sending_account('a@b.com', 'self_managed') }.to raise_error(ArgumentError)
      expect do
        warmup.add_sending_account('a@b.com', 'self_managed',
                                   engagement_rule_id: 0, email_content: { types_of_emails: ['newsletter'] })
      end.to raise_error(ArgumentError)
      expect(request_count).to eq(0)

      warmup.add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 2, ignore_conflict: true)
      expect(last_json).to eq(
        'from_address' => 'a@b.com', 'onboarding_model' => 'self_managed',
        'engagement_rule_id' => 2, 'ignore_conflict' => true
      )
    end

    it 'checks the zb_managed payload' do
      expect do
        warmup.add_sending_account('a@b.com', 'zb_managed',
                                   email_content: { types_of_emails: ['promotional'] })
      end.to raise_error(ArgumentError, /types_of_emails/)
      expect do
        warmup.add_sending_account('a@b.com', 'zb_managed', managed_sending: { timezone_offset: 15 })
      end.to raise_error(ArgumentError, /timezone_offset/)
      expect do
        warmup.add_sending_account('a@b.com', 'zb_managed',
                                   managed_sending: { warmup_start_date: '02/01/2026' })
      end.to raise_error(ArgumentError, /warmup_start_date/)
      expect(request_count).to eq(0)

      warmup.add_sending_account(
        'a@b.com', 'zb_managed',
        email_content: { types_of_emails: %w[newsletter marketing] },
        managed_sending: { timezone_offset: -5, warmup_start_date: Date.new(2026, 3, 4) }
      )
      body = last_json
      expect(body['onboarding_model']).to eq('zb_managed')
      expect(body['email_content']['types_of_emails']).to eq(%w[newsletter marketing])
      expect(body['managed_sending']['warmup_start_date']).to eq('2026-03-04')
    end

    it 'checks the from-address search and sends paging as strings' do
      expect { warmup.list_from_addresses(search_from: 'bad search!') }.to raise_error(ArgumentError)
      expect { warmup.list_from_addresses(offset: -1) }.to raise_error(ArgumentError)
      expect { warmup.list_from_addresses(limit: '10') }.to raise_error(ArgumentError)
      expect(request_count).to eq(0)

      warmup.list_from_addresses(search_from: 'a.b-c_d@e+f', offset: 0, limit: 50)
      expect(last_query).to include('search_from' => 'a.b-c_d@e+f', 'offset' => '0', 'limit' => '50')
    end

    it 'rejects a backwards date range and a bad date' do
      expect do
        warmup.statistics_per_day('a@b.com', '2026-02-02', '2026-01-01')
      end.to raise_error(ArgumentError, /later/)
      expect do
        warmup.statistics_per_day('a@b.com', '01/02/2026', '2026-01-01')
      end.to raise_error(ArgumentError, /YYYY-MM-DD/)
      expect(request_count).to eq(0)
    end

    it 'requires an email address for check_domain_dmarc, not a domain' do
      # LIVE: the API answers a bare domain with "Please provide a valid email
      # address", although the docs describe a domain.
      expect do
        warmup.check_domain_dmarc('example.com')
      end.to raise_error(ArgumentError, /email address/)
      expect(request_count).to eq(0)

      warmup.check_domain_dmarc('sender@example.com', dkim_selector: 'zb')
      expect(last_query).to include('from_address' => 'sender@example.com', 'dkim_selector' => 'zb')
    end

    it 'refuses a path id that would traverse' do
      ['.', '..', ' .. '].each do |bad|
        expect { warmup.custom_engagement(bad) }.to raise_error(ArgumentError, /invalid/)
      end
      expect(request_count).to eq(0)
    end

    it 'range-checks the SMTP port' do
      [0, 65_536, '587'].each do |bad|
        expect do
          warmup.test_smtp_configuration('a@b.com', 'u', 'p', 's', bad)
        end.to raise_error(ArgumentError, /port/)
      end
      expect(request_count).to eq(0)
    end
  end

  # -- responses ----------------------------------------------------------

  describe 'responses' do
    it 'returns nil for a documented empty success' do
      stub_ok('', status: 204)
      expect(warmup.delete_sending_account('a@b.com')).to be_nil

      stub_ok('', status: 200)
      expect(warmup.seed_count).to be_nil
    end

    it 'returns a list payload as it stands' do
      stub_ok('[{"seed":"a@b.com"},{"seed":"c@d.com"}]')
      expect(warmup.seeds.length).to eq(2)
    end

    it 'returns a bare number, which /seed-count answers with' do
      stub_ok('250')
      expect(warmup.seed_count).to eq(250)
    end

    it 'returns CSV downloads as text' do
      stub_ok("seed,provider\na@b.com,gmail\n", content_type: 'text/csv')
      expect(warmup.download_seeds).to eq("seed,provider\na@b.com,gmail\n")

      stub_ok("day,sent\n2026-01-01,10\n", content_type: 'text/csv')
      warmup.download_statistics('a@b.com')
      expect(last_query).to include('c_from' => 'a@b.com')
    end

    it 'treats a JSON error in place of a CSV as an error' do
      stub_ok('{"message":"No statistics for this address."}')
      expect do
        warmup.download_seeds
      end.to raise_error(Zerobounce::ApiResponseError, 'No statistics for this address.')
    end

    it 'puts the HTTP status on the error' do
      stub_ok('{"message":"Custom rule was updated less than 7 days ago."}', status: 429)
      expect { warmup.update_custom_engagement('a@b.com', 10, 10, 5) }
        .to raise_error(Zerobounce::ApiResponseError) { |error|
          expect(error.status_code).to eq(429)
          expect(error.message).to eq('Custom rule was updated less than 7 days ago.')
        }
    end

    it 'turns a validation error list into one short message' do
      stub_ok('{"detail":[{"loc":["body","reply_pct"],"msg":"ensure this value is <= 45"}]}',
              status: 422)
      expect { warmup.create_custom_engagement('a@b.com', 10, 10, 5) }
        .to raise_error(/reply_pct: ensure this value is <= 45/)
    end

    it 'turns a top-level string list into one short message' do
      stub_ok('["Sending account already exists."]', status: 400)
      expect do
        warmup.add_sending_account('a@b.com', 'self_managed', engagement_rule_id: 0)
      end.to raise_error(/Sending account already exists/)
    end

    it 'does not paste an HTML error page into the message' do
      stub_ok("<!DOCTYPE html><html><head><title>Access denied</title></head><body>#{'<p>blocked</p>' * 2000}</body></html>",
              status: 403, content_type: 'text/html')
      expect { warmup.seeds }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.status_code).to eq(403)
        expect(error.message.length).to be < 500
        expect(error.message).to include('HTML error page')
      }
    end

    it 'refuses a redirect rather than following it' do
      stub_ok('', status: 302)
      expect { warmup.seeds }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.status_code).to eq(302)
        expect(error.message).to include('redirect')
      }
    end

    it 'never puts the key in an error' do
      stub_ok(%({"message":"Invalid key #{api_key}"}), status: 401)
      expect { warmup.seeds }.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.message).not_to include(api_key)
        expect(error.message).to include('***')
      }
    end

    it 'never puts the SMTP credentials in an error' do
      stub_ok('{"message":"login failed for user bob with s3cret"}', status: 500)
      expect do
        warmup.test_smtp_configuration('a@b.com', 'bob', 's3cret', 'smtp.example.com', 587)
      end.to raise_error(Zerobounce::ApiResponseError) { |error|
        expect(error.message).not_to include('s3cret')
        expect(error.message).not_to include('bob')
        # LIVE: a failed SMTP login comes back as a 500, not a 4xx.
        expect(error.status_code).to eq(500)
      }
    end

    it 'does not leak a parser dump for a malformed body' do
      stub_ok("<<<not-json>>>#{'x' * 5000}")
      expect { warmup.seeds }.to raise_error(/not valid JSON/)
    end
  end
end
