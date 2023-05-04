
# Zerobounce
Ruby client for Zerobounce.net API. Developed based on [this version](https://github.com/afrase/zerobounce) by Aaron Frase.

## Usage
Add this line to your application's Gemfile:
```ruby
gem 'zerobounce'
```

And then execute:
```bash
$bundle
```

Or install it yourself as:
```bash
$gem install zerobounce
```

Import
```ruby
require 'zerobounce'
```

Set a valid ZeroBounce API key.
```ruby
Zerobounce.configure do |config|
  config.apikey = '<zerobounce-api-key>'
  ...
end
```
or 
```
Zerobounce.config.apikey = '<zerobounce-api-key>'
...
```

Credits
```ruby
Zerobounce.credits
=> 79   # returns -1 for invalid key
```

Usage statistics
```ruby
Zerobounce.api_usage(Date.today, Date.today)
=>
{"total"=>0,
 "status_valid"=>0,
 "status_invalid"=>0,
 "status_catch_all"=>0,
 "status_do_not_mail"=>0,
 "status_spamtrap"=>0,
 "status_unknown"=>0,
 "sub_status_toxic"=>0,
 "sub_status_disposable"=>0,
 "sub_status_role_based"=>0,
 "sub_status_possible_trap"=>0,
 "sub_status_global_suppression"=>0,
 "sub_status_timeout_exceeded"=>0,
 "sub_status_mail_server_temporary_error"=>0,
 "sub_status_mail_server_did_not_respond"=>0,
 "sub_status_greylisted"=>0,
 "sub_status_antispam_system"=>0,
 "sub_status_does_not_accept_mail"=>0,
 "sub_status_exception_occurred"=>0,
 "sub_status_failed_syntax_check"=>0,
 "sub_status_mailbox_not_found"=>0,
 "sub_status_unroutable_ip_address"=>0,
 "sub_status_possible_typo"=>0,
 "sub_status_no_dns_entries"=>0,
 "sub_status_role_based_catch_all"=>0,
 "sub_status_mailbox_quota_exceeded"=>0,
 "sub_status_forcible_disconnect"=>0,
 "sub_status_failed_smtp_connection"=>0,
 "sub_status_mx_forward"=>0,
 "sub_status_alternate"=>0,
 "sub_status_blocked"=>0,
 "sub_status_allowed"=>0,
 "start_date"=>"4/28/2023",
 "end_date"=>"4/28/2023"}
```

### Email Validation

Validate single eMail
```ruby
Zerobounce.validate('valid@example.com') 
# Zerobounce.validate('valid@example.com', '192.168.0.1') # optional IP address
=>
{"address"=>"valid@example.com",
 "status"=>"valid",
 "sub_status"=>"",
 "free_email"=>false,
 "did_you_mean"=>nil,
 "account"=>nil,
 "domain"=>nil,
 "domain_age_days"=>"9692",
 "smtp_provider"=>"example",
 "mx_found"=>"true",
 "mx_record"=>"mx.example.com",
 "firstname"=>"zero",
 "lastname"=>"bounce",
 "gender"=>"male",
 "country"=>nil,
 "region"=>nil,
 "city"=>nil,
 "zipcode"=>nil,
 "processed_at"=>"2023-04-28 15:18:45.631"}
```

Validate batch
```ruby
emails
=>
["disposable@example.com",
 "invalid@example.com",
 "valid@example.com",
 "toxic@example.com",
 "donotmail@example.com",
 "spamtrap@example.com"]
 
# ip_addresses 
=> ["192.168.0.1", "192.168.0.1", "192.168.0.1", "192.168.0.1", "192.168.0.1", "192.168.0.1"]
# Zerobounce.validate_batch(emails, ip_addresses) # optional ip_addresses parameter
 
Zerobounce.validate_batch(emails)
=>
[{"address"=>"disposable@example.com",
  "status"=>"do_not_mail",
  "sub_status"=>"disposable",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"},
 {"address"=>"invalid@example.com",
  "status"=>"invalid",
  "sub_status"=>"mailbox_not_found",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"},
 {"address"=>"valid@example.com",
  "status"=>"valid",
  "sub_status"=>"",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"},
 {"address"=>"toxic@example.com",
  "status"=>"do_not_mail",
  "sub_status"=>"toxic",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"},
 {"address"=>"donotmail@example.com",
  "status"=>"do_not_mail",
  "sub_status"=>"role_based",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"},
 {"address"=>"spamtrap@example.com",
  "status"=>"spamtrap",
  "sub_status"=>"",
  "free_email"=>false,
  "did_you_mean"=>nil,
  "account"=>nil,
  "domain"=>nil,
  "domain_age_days"=>"9692",
  "smtp_provider"=>"example",
  "mx_found"=>"true",
  "mx_record"=>"mx.example.com",
  "firstname"=>"zero",
  "lastname"=>"bounce",
  "gender"=>"male",
  "country"=>nil,
  "region"=>nil,
  "city"=>nil,
  "zipcode"=>nil,
  "processed_at"=>"2023-04-28 15:21:44.340"}]
```

#### Batch File Validation

Send file
```ruby
# sample file can be found in the files folder of this repository
 validate_file_path = File.join(Dir.pwd, 'files', 'validation.csv')
=> "/home/zb/wrappers/ruby-test/files/validation.csv"
 Zerobounce.validate_file_send(validate_file_path)
=>
{"success"=>true,
 "message"=>"File Accepted",
 "file_name"=>"validation.csv",
 "file_id"=>"75d854a6-565c-49f9-b4c8-b3344480ec4c"}
 # file_id will be required for next steps
 # optional named parameters: 
    email_address_column: 1,
    first_name_column: 2,
    last_name_column: 3,
    gender_column: 4,
    has_header_row: true,
    return_url: nil         # results callback url
 # Zerobounce.validate_file_send(validate_file_path, email_address_column: 1, gender_column: 4) 
```

Check file
```ruby
file_id = "75d854a6-565c-49f9-b4c8-b3344480ec4c"
=> "75d854a6-565c-49f9-b4c8-b3344480ec4c"
Zerobounce.validate_file_check(file_id)
=>
{"success"=>true,
 "file_id"=>"75d854a6-565c-49f9-b4c8-b3344480ec4c",
 "file_name"=>"validation.csv",
 "upload_date"=>"2023-04-28T15:25:41Z",
 "file_status"=>"Greylisted",
 "complete_percentage"=>"0%",
 "error_reason"=>nil,
 "return_url"=>nil}
```

Get file
```ruby
file_id = "75d854a6-565c-49f9-b4c8-b3344480ec4c"
=> "75d854a6-565c-49f9-b4c8-b3344480ec4c"
Zerobounce.validate_file_get(file_id)
=> "\"email\",\"first\",\"last\",\"gender\",\"ip\",\"ZB Status\",\"ZB Sub Status\",\"ZB Account\",\"ZB Domain\",\"ZB First Name\",\"ZB Last Name\",\"ZB Gender\",\"ZB Free Email\",\"ZB MX Found\",\"ZB MX Record\",\"ZB SMTP Provider\",\"ZB Did You Mean\"\n\"disposable@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"disposable\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"invalid@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"mailbox_not_found\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"valid@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"valid\",\"\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"toxic@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"toxic\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"donotmail@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"role_based\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"spamtrap@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"spamtrap\",\"\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"abuse@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"abuse\",\"\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"unknown@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"mail_server_temporary_error\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"catch_all@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"catch-all\",\"\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"antispam_system@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"antispam_system\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"does_not_accept_mail@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"does_not_accept_mail\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"exception_occurred@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"exception_occurred\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"failed_smtp_connection@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"failed_smtp_connection\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"failed_syntax_check@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"failed_syntax_check\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"forcible_disconnect@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"forcible_disconnect\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"global_suppression@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"global_suppression\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"greylisted@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"greylisted\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"leading_period_removed@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"valid\",\"leading_period_removed\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"mail_server_did_not_respond@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"mail_server_did_not_respond\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"mail_server_temporary_error@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"mail_server_temporary_error\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"mailbox_quota_exceeded@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"mailbox_quota_exceeded\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"mailbox_not_found@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"mailbox_not_found\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"no_dns_entries@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"no_dns_entries\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"possible_trap@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"possible_trap\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"possible_typo@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"possible_typo\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"role_based@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"role_based\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"timeout_exceeded@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"unknown\",\"timeout_exceeded\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"unroutable_ip_address@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"invalid\",\"unroutable_ip_address\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"free_email@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"valid\",\"\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"True\",\"true\",\"mx.example.com\",\"example\",\"\"\n\"role_based_catch_all@example.com\",\"First\",\"Last\",\"male\",\"127.0.0.1\",\"do_not_mail\",\"role_based_catch_all\",\"\",\"\",\"zero\",\"bounce\",\"male\",\"False\",\"true\",\"mx.example.com\",\"example\",\"\"\n"
```

Delete file
```ruby
file_id = "75d854a6-565c-49f9-b4c8-b3344480ec4c"
=> "75d854a6-565c-49f9-b4c8-b3344480ec4c"
Zerobounce.validate_file_delete(file_id)
=>
{"success"=>true,
 "message"=>"File Deleted",
 "file_name"=>"validation.csv",
 "file_id"=>"75d854a6-565c-49f9-b4c8-b3344480ec4c"}
```

### AI Scoring

Send file
```ruby
scoring_file_path = File.join(Dir.pwd, 'files', 'scoring.csv')
=> "/home/odin/zb/wrappers/ruby-test/files/scoring.csv"
Zerobounce.scoring_file_send(scoring_file_path)
=>
{"success"=>true,
 "message"=>"File Accepted",
 "file_name"=>"scoring.csv",
 "file_id"=>"89fb7262-b845-4fa1-aa25-e486347ec64e"}
# file_id will be required for the next steps
# optional named parameters
    email_address_column: 1,
    has_header_row: true,
    return_url: nil         # results callback url
# Zerobounce.scoring_file_send(scoring_file_path, email_address_column: 1)
```

File check
```ruby
file_id = "89fb7262-b845-4fa1-aa25-e486347ec64e"
=> "89fb7262-b845-4fa1-aa25-e486347ec64e"
Zerobounce.scoring_file_check(file_id)
=>
{"success"=>true,
 "file_id"=>"89fb7262-b845-4fa1-aa25-e486347ec64e",
 "file_name"=>"scoring.csv",
 "upload_date"=>"2023-04-28T16:57:18Z",
 "file_status"=>"Complete",
 "complete_percentage"=>"100% Complete.",
 "return_url"=>nil}
```

Get file
```ruby
file_id = "89fb7262-b845-4fa1-aa25-e486347ec64e"
=> "89fb7262-b845-4fa1-aa25-e486347ec64e"
Zerobounce.scoring_file_get(file_id)
=> "\"email\",\"ZeroBounceQualityScore\"\r\n\"disposable@example.com\",\"0\"\r\n\"invalid@example.com\",\"10\"\r\n\"valid@example.com\",\"10\"\r\n\"toxic@example.com\",\"2\"\r\n\"donotmail@example.com\",\"0\"\r\n\"spamtrap@example.com\",\"0\"\r\n\"abuse@example.com\",\"10\"\r\n\"unknown@example.com\",\"10\"\r\n\"catch_all@example.com\",\"10\"\r\n\"antispam_system@example.com\",\"0\"\r\n\"does_not_accept_mail@example.com\",\"0\"\r\n\"exception_occurred@example.com\",\"0\"\r\n\"failed_smtp_connection@example.com\",\"0\"\r\n\"failed_syntax_check@example.com\",\"0\"\r\n\"forcible_disconnect@example.com\",\"0\"\r\n\"global_suppression@example.com\",\"0\"\r\n\"greylisted@example.com\",\"0\"\r\n\"leading_period_removed@example.com\",\"0\"\r\n\"mail_server_did_not_respond@example.com\",\"0\"\r\n\"mail_server_temporary_error@example.com\",\"0\"\r\n\"mailbox_quota_exceeded@example.com\",\"0\"\r\n\"mailbox_not_found@example.com\",\"0\"\r\n\"no_dns_entries@example.com\",\"0\"\r\n\"possible_trap@example.com\",\"0\"\r\n\"possible_typo@example.com\",\"0\"\r\n\"role_based@example.com\",\"0\"\r\n\"timeout_exceeded@example.com\",\"0\"\r\n\"unroutable_ip_address@example.com\",\"0\"\r\n\"free_email@example.com\",\"0\"\r\n\"role_based_catch_all@example.com\",\"0\""
```

Delete file
```ruby
file_id = "89fb7262-b845-4fa1-aa25-e486347ec64e"
=> "89fb7262-b845-4fa1-aa25-e486347ec64e"
Zerobounce.validate_file_delete(file_id)
=> {"success"=>false, "message"=>"File cannot be found."}
```


## Development

After checking out the repo run tests
```bash
rspec --init # if needed
bundle exec rspec
```

You should see an output like this
```bash
Run options: include {:focus=>true}
running live tests
.....................................................

Finished in 6.81 seconds (files took 0.40587 seconds to load)
53 examples, 0 failures
```

### Test parameters
The tests use the following environment parameters:
TEST {unit|live} influences whether mocked unit tests are run or the live server is used (credits may be used if you choose to do this)
ZEROBOUNCE_API_KEY {<zerobounce-api-key-value>} this key is used to make requests to the live server; it is also used in mock tests as a valid key sample (any value will work for mock tests)

To set them
```bash
export ZEROBOUNCE_API_KEY=<zerobounce-api-key-value>
export ZEROBOUNCE_API_KEY=
export TEST=unit
```

A .env.sample file is provided.
