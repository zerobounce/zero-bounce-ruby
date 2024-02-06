# frozen_string_literal: true
require 'dotenv'

RSpec.configure do |config|
    if File.file?(".env") then Dotenv.load(".env") else Dotenv.load end
    config.around(mock_env: true) do |example|
    original_env = ENV.to_h

    begin
      example.run
    ensure
      ENV.clear
      ENV.update(original_env)
    end
  end
end
