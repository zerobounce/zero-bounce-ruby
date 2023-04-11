# frozen_string_literal: true

RSpec.describe Zerobounce::Request do
  describe '.new' do

    context 'check headers' do
      it 'uses Zerobounce::Configuration#headers' do
        expect(described_class.new.headers).to be(Zerobounce.config.headers)
      end
    end


    context 'check host' do
      it 'uses Zerobounce::Configuration#host' do
        expect(described_class.new.host).to be(Zerobounce.config.host)
      end
    end
  end

  describe 'API V2' do
    describe '#validate' do
      it 'returns a response' do
        expect(described_class.new.validate(email: 'user@example.com')).to be_a(Hash)
      end
    end

    describe '#credits' do
      it 'returns an integer' do
        expect(described_class.new.credits).to be_an(Integer)
      end
    end
  end
end
