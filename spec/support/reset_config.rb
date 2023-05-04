# frozen_string_literal: true

RSpec.configure do |config|
  config.after do
    Zerobounce.config.apikey = nil
  end
end
