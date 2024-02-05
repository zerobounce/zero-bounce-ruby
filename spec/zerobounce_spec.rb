# frozen_string_literal: true

describe Zerobounce, :focus => ENV['TEST']!='unit' do


	let (:valid_api_key) { ENV['ZEROBOUNCE_API_KEY'] }
	let (:invalid_api_key) { ENV['INCORRECT_API_KEY'] }

        it 'should run live tests' do
                puts 'running live tests'
        end

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




	describe '.activity' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.activity('ss@gmail.com') }.to \
					raise_error(StandardError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.activity('ss@gmail.com') }.to \
					raise_error(RestClient::Forbidden)
					# raise_error(StandardError,
					# 	/Invalid API key or your account ran out of credits/)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given no email address' do
				it 'should raise an error' do
					expect{ described_class.activity() }.to \
						raise_error(ArgumentError)
				end
			end
			context 'given a valid email address' do
				it 'should return a valid result' do
					result = described_class.activity('ss@gmail.com')
					expect(result).to be_a_kind_of(Hash)
					expect(result).to include(
						'found', 'active_in_days'
					)
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
				expect{ described_class.credits }.to \
					raise_error(RestClient::Forbidden)
				# expect(described_class.credits).to equal(-1)
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
		context 'wrong number of parameters' do
			it 'should raise ArgumentError' do
				expect{ described_class.api_usage }.to raise_error(ArgumentError)
				expect{ described_class.api_usage(Date.today) }.to \
					raise_error(ArgumentError)
				expect{ described_class.api_usage(Date.today, 'b') }.to \
					raise_error(ArgumentError)
			end
		end
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.api_usage(Date.today, Date.today)}.to \
					raise_error(StandardError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.api_usage(Date.today, Date.today) }.to \
					raise_error(RestClient::Forbidden)
					# raise_error(RuntimeError, /Invalid API key/)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			it 'should return API usage statistics' do
				result = described_class.api_usage(Date.today, Date.today)
				expect(result).to be_a_kind_of(Hash)
					expect(result).to include(
						'total', 'status_valid', 'status_invalid', 'status_catch_all',
						'status_do_not_mail', 'status_spamtrap', 'status_unknown'
					)
			end
		end
	end

	let (:emails) {[
		'disposable@example.com',
		'invalid@example.com',
		'valid@example.com',
		'toxic@example.com',
		'donotmail@example.com',
		'spamtrap@example.com'
	]}

	describe '.validate_batch' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.validate_batch(emails) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate_batch(emails) }.to \
					raise_error(RestClient::Forbidden)
					# raise_error(RuntimeError,
					# 	/Invalid API Key or your account ran out of credits/)
			end
		end
		context 'given correct API key' do
			context 'given incorrect input (no emails)' do
				it 'should raise an ArgumentError' do
					expect{ described_class.validate_batch }.to \
						raise_error(ArgumentError)
				end
			end
			context 'given incorrect input (emails not array of strings)' do
				it 'should raise an ArgumentError' do
					expect{ described_class.validate_batch('valid@example.com') }.to \
						raise_error(ArgumentError)
					expect{ described_class.validate_batch([1, 2, 3]) }.to \
						raise_error(ArgumentError)
				end
			end
			context 'given correct input' do
				before do
					described_class.config.apikey = valid_api_key
				end
				it 'should return valid results' do
					results = described_class.validate_batch(emails)
					expect(results.length).to be(6)
					results.each do |result|
						expect(result).to include(
							'address', 'status', 'sub_status', 'domain_age_days',
							'smtp_provider', 'mx_found', 'mx_record'
						)
					end
				end
			end
		end
	end


	let(:validate_file_path){File.join(Dir.pwd, 'files', 'validation.csv')}
	validate_file_id = nil
	describe '.validate_file_send' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.validate_file_send(validate_file_path) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate_file_send(validate_file_path) }.to \
					raise_error(RestClient::Unauthorized)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file format' do
				# todo:
			end
			context 'given correct file format' do
				it 'should return a correct upload result' do
					results = described_class.validate_file_send(validate_file_path)
					expect(results).to be_a_kind_of(Hash)
					expect(results['success']).to be(true)
					expect(results['message']).to eql('File Accepted')
					expect(results['file_id']).to be_a_kind_of(String)
					validate_file_id = results['file_id']
					expect(results['file_name']).to eql('validation.csv')
				end
			end
		end
	end

	describe '.validate_file_check' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.validate_file_check(validate_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate_file_check(validate_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return error message' do
					results = described_class.validate_file_check('invalid-file-id')
					expect(results['success']).to be(false)
					expect(results['message']).to eql('File cannot be found.')
				end
			end
			context 'given correct file id' do
				it 'should return file processing progress' do
					results = described_class.validate_file_check(validate_file_id)
					expect(results['success']).to be(true)
					expect(results['file_id']).to be_a_kind_of(String)
					expect(results['file_id']).to eql(validate_file_id)
					expect(results['file_name']).to be_a_kind_of(String)
					expect(results['error_reason']).to be(nil)
				end
			end
		end
	end

	describe '.validate_file_get' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.validate_file_get(validate_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate_file_get(validate_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return error message' do
					expect{ described_class.validate_file_get('invalid-file-id') }.to \
						raise_error(RestClient::Forbidden)
					# results = described_class.validate_file_get('invalid-file-id')
					# expect(results['success']).to be(false)
					# expect(results['message']).to eql('File cannot be found.')
				end
			end
			context 'given correct file id' do
				before do
					described_class.config.apikey = valid_api_key
				end
				it 'should download file contents' do
					# results = described_class.validate_file_get(validate_file_id)
					# expect(results.class).to be(String)
				end
			end
		end
	end

	describe '.validate_file_delete' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.validate_file_delete(validate_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.validate_file_delete(validate_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return error message' do
					expect{ described_class.validate_file_delete('invalid-file-id') }.to \
						raise_error(RestClient::Forbidden)
					# results = described_class.validate_file_delete('invalid-file-id')
					# expect(results['success']).to be(false)
					# expect(results['message']).to eql('File cannot be found.')
				end
			end
			context 'given correct file id' do
				it 'should return deleted response' do
					# results = described_class.validate_file_delete(validate_file_id)
					# expect(results['success']).to be(true)
					# expect(results['message']).to eql('File Deleted')
					# expect(results['file_name']).to eql('validation.csv')
					# expect(results['file_id']).to be_a_kind_of(String)
					# expect(results['file_id']).to eql(validate_file_id)
				end
			end
		end
	end

	let(:scoring_file_path){File.join(Dir.pwd, 'files', 'scoring.csv')}
	scoring_file_id = nil
	describe '.scoring_file_send' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_send(scoring_file_path) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_send(scoring_file_path) }.to \
					raise_error(RestClient::Unauthorized)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file format' do
				# todo:
			end
			context 'given correct file format' do
				it 'should return a correct upload result' do
					results = described_class.scoring_file_send(scoring_file_path)
					expect(results).to be_a_kind_of(Hash)
					expect(results['success']).to be(true)
					expect(results['message']).to eql('File Accepted')
					expect(results['file_id']).to be_a_kind_of(String)
					scoring_file_id = results['file_id']
					expect(results['file_name']).to eql('scoring.csv')
				end
			end
		end
	end

	describe '.scoring_file_check' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_check(scoring_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_check(scoring_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return an error message' do
					expect{ described_class.scoring_file_check('invalid-file-id') }.to \
						raise_error(RestClient::Forbidden)
					# results = described_class.scoring_file_check('invalid-file-id')
					# expect(results['success']).to be(false)
					# expect(results['message']).to eql('file_id is invalid.')
				end
			end
			context 'given correct file id' do
				it 'should return file processing progress' do
					results = described_class.scoring_file_check(scoring_file_id)
					expect(results['success']).to be(true)
					expect(results['file_id']).to be_a_kind_of(String)
					expect(results['file_id']).to eql(scoring_file_id)
					expect(results['file_name']).to be_a_kind_of(String)
					expect(results['error_reason']).to be(nil)
				end
			end
		end
	end

	describe '.scoring_file_get' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_get(scoring_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_get(scoring_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return an error' do
					expect{ described_class.scoring_file_get('invalid-file-id') }.to \
						raise_error(RestClient::Forbidden)
					# results = described_class.scoring_file_get('invalid-file-id')
					# expect(results['success']).to be(false)
					# expect(results['message']).to eql('file_id is invalid.')
				end
			end
			context 'given correct file id' do
				before do
					described_class.config.apikey = valid_api_key
				end
				it 'should download file contents' do
					results = described_class.scoring_file_get(scoring_file_id)
					expect(results.class).to be(String)
				end
			end
		end
	end

	describe '.scoring_file_delete' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_delete(scoring_file_id) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise an API key error' do
				expect{ described_class.scoring_file_delete(scoring_file_id) }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given incorrect file id' do
				it 'should return an error' do
					expect{ described_class.scoring_file_delete('invalid-file-id') }.to \
						raise_error(RestClient::Forbidden)
					# results = described_class.scoring_file_delete('invalid-file-id')
					# expect(results['success']).to be(false)
					# expect(results['message']).to eql('file_id is invalid.')
				end
			end
			context 'given correct file id' do
				it 'should return the correct file deleted response' do
					results = described_class.scoring_file_delete(scoring_file_id)
					expect(results['success']).to be(true)
					expect(results['message']).to eql('File Deleted')
					expect(results['file_name']).to eql('scoring.csv')
					expect(results['file_id']).to be_a_kind_of(String)
				end
			end
		end
	end

	describe '.guessformat' do
		context 'given no API key' do
			it 'should raise an API key error' do
				expect{ described_class.guessformat(
					'example.com',
					first_name: 'John',
					middle_name: 'Deere',
					last_name: 'Doe'
				) }.to \
					raise_error(RuntimeError, /API key must be assigned/)
			end
		end
		context 'given incorrect API key' do
			before do
				described_class.config.apikey = invalid_api_key
			end
			it 'should raise a forbidden error' do
				expect{ described_class.guessformat(
					'example.com',
					first_name: 'John',
					middle_name: 'Deere',
					last_name: 'Doe') }.to \
					raise_error(RestClient::Forbidden)
			end
		end
		context 'given correct API key' do
			fields = ['email', 'domain', 'format', 'status',
				'sub_status', 'confidence', 'did_you_mean',
				'other_domain_formats']
			before do
				described_class.config.apikey = valid_api_key
			end
			context 'given no domain' do
				it 'should raise an error' do
					expect{ described_class.guessformat() }.to \
						raise_error(ArgumentError)
				end
				it 'should raise an error' do
					expect{ described_class.guessformat(
						first_name: 'John') }.to \
						raise_error(ArgumentError)
				end
			end
			context 'given a valid domain' do
				context 'given no names' do
					it 'should return a valid result' do
						result = described_class.guessformat(
							'zerobounce.net')
						expect(result).to be_a_kind_of(Hash)
						expect(result).to include(*fields)
					end
				end
				context 'given first name' do
					it 'should return a valid result' do
						result = described_class.guessformat(
							'zerobounce.net',
							first_name: 'John')
						expect(result).to be_a_kind_of(Hash)
						expect(result).to include(*fields)
					end
				end
				context 'given last name'do
					it 'should return a valid result' do
						result = described_class.guessformat(
							'zerobounce.net',
							last_name: 'Doe')
						expect(result).to be_a_kind_of(Hash)
						expect(result).to include(*fields)
					end
				end
				context 'given first, last, and, middle names' do
					it 'should return a valid result' do
						result = described_class.guessformat(
							'zerobounce.net',
							first_name: 'John',
							middle_name: 'Deere',
							last_name: 'Doe')
						expect(result).to be_a_kind_of(Hash)
						expect(result).to include(*fields)
					end
				end
			end
		end
	end

end
