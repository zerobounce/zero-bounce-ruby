# frozen_string_literal: true

RSpec.describe Zerobounce::Request do
  describe '.new' do

    context 'when headers in params' do
      let(:headers) { { user_agent: 'foobar' } }

      it 'uses the headers' do
        expect(described_class.new(headers: headers).headers).to be(headers)
      end
    end

    context 'when headers not in params' do
      it 'uses Zerobounce::Configuration#headers' do
        expect(described_class.new.headers).to be(Zerobounce.config.headers)
      end
    end

    context 'when host in params' do
      let(:host) { 'http://example.com' }

      it 'uses the host' do
        expect(described_class.new(host: host).host).to be(host)
      end
    end

    context 'when host not in params' do
      it 'uses Zerobounce::Configuration#host' do
        expect(described_class.new.host).to be(Zerobounce.config.host)
      end
    end
  end

  describe 'API V2' do
    describe '#validate' do
      it 'returns a response' do
        expect(described_class.new.validate(email: 'user@example.com')).to be_a(Zerobounce::Response)
      end
    end

    describe '#credits' do
      it 'returns an integer' do
        expect(described_class.new.credits).to be_an(Integer)
      end
    end
  end
end
