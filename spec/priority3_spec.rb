# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe Zerobounce do
  let(:api_key) { 'dummy_key' }

  before do
    Zerobounce.configure { |c| c.apikey = api_key }
  end

  it 'send_email_finder_file posts to bulk email-finder sendfile' do
    fixture = File.join(Dir.pwd, 'spec', 'fixtures', 'priority3_finder.csv')
    FileUtils.mkdir_p(File.dirname(fixture))
    File.write(fixture, "domain,name\nacme.com,Jane\n")

    stub_request(:post, %r{\Ahttps://bulkapi\.zerobounce\.net/email-finder/sendfile})
      .to_return(
        status: 200,
        body: '{"success":true,"file_id":"f1","file_name":"out.csv"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Zerobounce.send_email_finder_file(fixture, domain_column: 1)
    expect(result['success']).to be true
  end

  it 'validate_s3_file posts to bulk validateS3file' do
    stub_request(:post, %r{\Ahttps://bulkapi\.zerobounce\.net/validateS3file})
      .to_return(
        status: 200,
        body: '{"success":true}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Zerobounce.validate_s3_file(file_name: 'bucket/key.csv')
    expect(result['success']).to be true
  end

  it 'list_s3_files gets bulk listS3files' do
    stub_request(:get, %r{\Ahttps://bulkapi\.zerobounce\.net/v2/listS3files})
      .to_return(
        status: 200,
        body: '[{"file_name":"bucket/key.csv"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Zerobounce.list_s3_files(bucket: 'my-bucket', search: 'key')
    expect(result).to be_an(Array)
    expect(result.first['file_name']).to eq('bucket/key.csv')
  end
end
