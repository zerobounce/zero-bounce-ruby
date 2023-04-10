# frozen_string_literal: true

RSpec.describe Zerobounce::Configuration do
  it 'has correct attributes' do
    expect(described_class.new).to have_attributes(
      apikey: be_nil, host: be_a(String), headers: be_a(Hash), valid_statuses: be_an(Array)
    )
  end

  describe '#apikey', mock_env: true do
    before { ENV['ZEROBOUNCE_API_KEY'] = 'foobar' }

    it 'uses the environment variable "ZEROBOUNCE_API_KEY" by default' do
      expect(described_class.new.apikey).to eq('foobar')
    end
  end
end
