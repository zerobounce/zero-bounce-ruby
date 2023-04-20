
RSpec.describe Zerobounce do

	let (:valid_api_key) { 'd1c0448d296846c9b227a5dc3fa8c605' }
	let (:invalid_api_key) { [*('a'..'z'),*('0'..'9')].sample(32).join }

	it 'should generate different keys' do
		expect(valid_api_key).not_to equal(invalid_api_key)
	end

	it 'has a version number' do 
		expect(described_class::VERSION).not_to be_nil
	end
	
	describe '.configure' do
		it 'yields the configuration' do
			expect { |b| described_class.configure(&b) }.to \
				yield_with_args(described_class::Configuration)
		end
		it 'sets the api key in configure block' do
     		described_class.configure {|config| config.apikey = valid_api_key}
    		expect(described_class.configuration.apikey).to eq(valid_api_key)

    		described_class.configure {|config| config.apikey = invalid_api_key}
    		expect(described_class.configuration.apikey).to eq(invalid_api_key)
    	end
	end

	describe '.configuration' do
    	it 'returns the same configuration instance' do
      		expect(described_class.configuration).to \
      			equal(described_class.configuration)
    	end
  	end

	describe '.validate' do
		context 'given no API key' do
			it 'should raise an API key error' do 
				expect{ described_class.validate('valid@example.com') }.to \
					raise_error(StandardError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate('valid@example.com') }.to \
					raise_error(StandardError, 
						/Invalid API key or your account ran out of credits/)
			end
		end
		context 'given correct API key' do 
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given no email address' do 
				it 'should raise an error' do 
					expect{ described_class.validate() }.to \
						raise_error(ArgumentError)
				end
			end
			context 'given a valid email address' do
				it 'should return a valid result' do
					result = described_class.validate('valid@example.com')
					expect(result).to be_a_kind_of(Hash)
					expect(result).to include(
						'address', 'status', 'sub_status', 'domain_age_days', 
						'smtp_provider', 'mx_found', 'mx_record'
					)
				end 
				context 'given an IP address' do
					it 'should return a valid result' do # todo: this works with any address
						result = described_class.validate('valid@example.com', '127.0.0.1')
						expect(result).to be_a_kind_of(Hash)
						expect(result).to include(
							'address', 'status', 'sub_status', 'domain_age_days', 
							'smtp_provider', 'mx_found', 'mx_record'
						)	
					end
				end
			end
		end
	end

	describe '.credits' do
		context 'given no API key' do
			it 'should raise an API key error' do 
				expect{ described_class.credits }.to \
					raise_error(StandardError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should return -1 credits' do
				expect(described_class.credits).to equal(-1)
			end
		end
		context 'given correct API key' do 
			before do
				described_class.config.apikey = valid_api_key
			end
			it 'should return the correct number of credits' do 
				expect(described_class.credits).to satisfy { |n| n > -1 }
			end
		end
	end

	describe '.api_usage' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			it 'should return API usage statistics' do 
			end
		end
	end

	describe '.validate_batch' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect input (no email_address)' do 

			end
			context 'given correct input' do 
				it 'should return valid results' do
				end
			end
		end
	end

	describe '.validate_file_send' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file format' do
			end
			context 'given correct file format' do 
			end
		end
	end

	describe '.validate_file_check' do 
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return error message' do
				end
			end
			context 'given deleted file id' do 
				it 'should return errir message' do
				end
			end
			context 'given correct file id' do
				it 'should return file processing progress' do
				end
			end
		end
	end 

	describe '.validate_file_get' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return error message' do
				end
			end
			context 'given deleted file id' do 
				it 'should return error message' do
				end
			end
			context 'given correct file id' do
				it 'should download file contents' do 
				end
			end
		end
	end

	describe '.validate_file_delete' do 
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return error message' do
				end
			end
			context 'given deleted file id' do 
				it 'should return error message' do
				end
			end
			context 'given correct file id' do
				it 'should return deleted response' do
				end
			end
		end
	end

	describe '.scoring_file_send' do 
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file format' do
			end
			context 'given correct file format' do 
			end
		end
	end

	describe '.scoring_file_check' do 
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return an error' do
				end
			end
			context 'given deleted file id' do 
				it 'should return an error' do 
				end
			end
			context 'given correct file id' do
				it 'should return correct file status' do
				end
			end
		end
	end

	describe '.scoring_file_get' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return an error' do 
				end
			end
			context 'given deleted file id' do 
				it 'should return an error' do
				end
			end
			context 'given correct file id' do
				it 'should download file contents' do
				end
			end
		end
	end

	describe '.scoring_file_delete' do
		context 'given no API key' do
			it 'should raise an API key error' do 
			end
		end
		context 'given incorrect API key' do
			it 'should raise an API key error' do
			end
		end
		context 'given correct API key' do 
			context 'given incorrect file id' do
				it 'should return an error' do
				end
			end
			context 'given deleted file id' do 
				it 'should return an error' do 
				end
			end
			context 'given correct file id' do
				it 'should return the correct file deleted response' do 
				end
			end
		end
	end

end
