# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe 'Bulk getfile v2' do
  describe 'download sniff (JSON bodies are never file content)' do
    let(:bulk) { %r{\Ahttps://bulkapi\.zerobounce\.net/v2/(scoring/)?getfile} }
    let(:calls) do
      [-> { Zerobounce.validate_file_get('f1') }, -> { Zerobounce.scoring_file_get('f1') }]
    end

    before { Zerobounce.configure { |c| c.apikey = 'test-key-bulk-v2' } }

    {
      'array' => ['text/csv', '[1,2]'],
      'neutral object' => ['text/csv', '{"foo":1}'],
      'BOM + success false' => ['text/csv', "\uFEFF{\"success\":false,\"message\":\"No such file\"}"],
      'BOM bytes' => ['text/csv', "\xEF\xBB\xBF{\"message\":\"No such file\"}".b],
      'problem+json, JSON body' => ['application/problem+json; charset=utf-8', '{"detail":"No such file"}'],
      'problem+json, text body' => ['application/problem+json', 'plain text'],
      'vnd +json' => ['application/vnd.api+json', 'x,y']
    }.each do |name, (ct, body)|
      it "raises on #{name} with status 200, never returning the body" do
        calls.each do |call|
          stub_request(:get, bulk).to_return(status: 200, body: body, headers: { 'Content-Type' => ct })
          expect { call.call }.to raise_error(Zerobounce::ApiResponseError) { |e| expect(e.status_code).to eq(200) }
        end
      end
    end

    it 'still returns a CSV that merely starts with a bracket-less header' do
      stub_request(:get, bulk)
        .to_return(status: 200, body: "{not json,x\n1,2\n", headers: { 'Content-Type' => 'text/csv' })
      expect(Zerobounce.validate_file_get('f1')).to eq("{not json,x\n1,2\n")
    end
  end

  let(:api_key) { ENV.fetch('ZEROBOUNCE_API_KEY', 'test-key-bulk-v2') }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  describe 'Zerobounce.get_file_json_indicates_error?' do
    it 'detects success false JSON' do
      expect(Zerobounce.get_file_json_indicates_error?('{"success":false,"message":""}')).to be(true)
    end

    it 'treats any JSON object or array as an API answer, not a file' do
      ['{"file_id":"x"}', '[1,2]', "\uFEFF{\"success\":false}"].each do |body|
        expect(Zerobounce.get_file_json_indicates_error?(body)).to be(true), body
      end
    end

    it 'leaves CSV and malformed JSON alone' do
      ['a,b', '{not json', '[broken', ''].each do |body|
        expect(Zerobounce.get_file_json_indicates_error?(body)).to be(false), body
      end
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
