# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe 'Bulk getfile v2' do
  let(:api_key) { ENV.fetch('ZEROBOUNCE_API_KEY', 'test-key-bulk-v2') }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  describe 'Zerobounce.get_file_json_indicates_error?' do
    it 'detects success false JSON' do
      expect(Zerobounce.get_file_json_indicates_error?('{"success":false,"message":""}')).to be(true)
    end

    it 'returns false for neutral JSON without error shape' do
      expect(Zerobounce.get_file_json_indicates_error?('{"file_id":"x"}')).to be(false)
    end
  end

  describe '.validate_file_get with GetFileOptions' do
    let(:file_id) { '84946fc8-3f89-428a-9d0d-382fbe18cb24' }

    before do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/getfile})
        .with(
          query: hash_including(
            'api_key' => api_key,
            'file_id' => file_id,
            'download_type' => 'combined',
            'activity_data' => 'true'
          )
        )
        .to_return(status: 200, body: "a,b\n", headers: { 'Content-Type' => 'text/csv' })
    end

    it 'sends download_type and activity_data' do
      opts = Zerobounce::GetFileOptions.new(
        download_type: Zerobounce::DownloadType::COMBINED,
        activity_data: true
      )
      expect(Zerobounce.validate_file_get(file_id, opts)).to eq("a,b\n")
    end
  end

  describe '.scoring_file_get with GetFileOptions' do
    let(:file_id) { 'f1' }

    before do
      stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/scoring/getfile})
        .with(
          query: hash_including(
            'api_key' => api_key,
            'file_id' => file_id,
            'download_type' => 'phase_2'
          )
        )
        .to_return(status: 200, body: "x,y\n", headers: { 'Content-Type' => 'text/csv' })
    end

    it 'sends download_type but not activity_data' do
      opts = Zerobounce::GetFileOptions.new(
        download_type: Zerobounce::DownloadType::PHASE_2,
        activity_data: true
      )
      expect(Zerobounce.scoring_file_get(file_id, opts)).to eq("x,y\n")
    end
  end
end
