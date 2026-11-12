# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `validate_file_send_stream` and `scoring_file_send_stream` work again. From 2.0.1 to 3.0.1 they raised `ArgumentError` ("File path must be under the current directory") whenever the system temp directory is outside the current directory, as it usually is: they wrote the content to a Tempfile in the system temp directory and uploaded its path, which the path check added in 2.0.1 rejects. 2.0.0 was not affected. The content is now uploaded from memory under the given `file_name` (2.0.0 sent the temp file's random name); file paths passed to `validate_file_send` and the other upload methods are still checked as before.
- A response whose body is cut short (the connection closes before `Content-Length` bytes arrive) raises `Zerobounce::ApiResponseError` with `status_code` 0 on every request, including the result-file downloads and `Zerobounce::Warmup`. Up to 3.0.1 Net::HTTP returned the bytes that had arrived, so a truncated result file or JSON body after a 200 header was returned as a success.
- `Zerobounce::Warmup#download_seeds` and `#download_statistics` raise `Zerobounce::ApiResponseError` (with the HTTP status) for an HTML page on a 200, such as a proxy's "Access denied" page, as the Python SDK does. Up to 3.0.1 the page was returned as the CSV text.

## [3.0.1] - 2026-11-11

### Fixed

- `validate` without an IP address leaves `ip_address` out of the request. 3.0.0 sent a bare `ip_address` parameter with no value. An IP address that is given, including `'0'`, is still sent.
- `send_list_evaluator_file` uploads to `list_evaluator_root_url` (`ZEROBOUNCE_LIST_EVALUATOR_URL`), as `get_list_evaluator_result` already did. 3.0.0 posted to `bulk_api_root_url` + `listevaluator/` and ignored the setting. With the default URLs the request is unchanged (`https://bulkapi.zerobounce.net/v2/listevaluator/`).
- The S3 and SFTP/FTP jobs derive their root from `bulk_api_root_url` after dropping trailing slashes, so `bulk_api_root_url = 'https://host/v2//'` sends them to `https://host/listS3files` instead of `https://host/v2/listS3files`. A `bulk_root_url` that is set is used as before.

### Security

- A `Zerobounce::Warmup` transport error (for example a `SocketError`) no longer keeps the unredacted original error as `#cause`, which `#full_message` prints. Its own message was already redacted; the main client's errors already dropped the cause.

## [3.0.0] - 2026-11-12

### Breaking

- **Breaking:** boolean options are parsed strictly. `true`/`false`, `'true'`/`'false'` (any case) and `1`/`0` are accepted; anything else raises `ArgumentError` naming the option before a request is sent. Up to 2.2.0 any truthy value was sent as `true`, so `activity_data: 'false'` sent `true`. Affects `validate` (`activity_data`, `verify_plus`, `domain_info`, `greylist_processing`), `validate_batch`, `validate_file_send`/`scoring_file_send` (`has_header_row`, `allow_phase_2`), `GetFileOptions#activity_data`, `send_email_finder_file`, `send_domain_search_file`, and the S3/SFTP jobs (`has_header_row`, `remove_duplicates`); a `nil` `has_header_row` on an S3/SFTP job, which 2.2.0 sent as `false`, now raises.
- **Breaking:** an API key with surrounding whitespace or control characters (for example one read from a file with its newline) raises `ArgumentError` before any request, from `Zerobounce.configure`'s key, `Zerobounce.with_api_key` and `Zerobounce::Client.new`, as `Zerobounce::Warmup.new` already did. 2.2.0 sent it as it was.

### Fixed

- `validate` returns the greylist answer `{"Message": "Greylist validation still in progress..."}` as its result (GET and `use_post: true`). 2.2.0 raised `RuntimeError` for it, so `greylist_processing: true` could never be used to pick up a result later.
- A 2xx `{"error_message": "..."}` with no `success` field raises. 2.2.0 returned it as the result, and `credits` returned `0` for it.
- `find_email`, `find_domain` and `guessformat` raise for a body made only of message fields (`detail`, `error_message`, `message`, as well as `Message`); 2.2.0 returned `{"detail": ...}` and `{"error_message": ...}` as results.
- `validate_file_get`, `scoring_file_get` and the email finder and domain search downloads raise `Empty response from ZeroBounce (HTTP 200)` for an empty body instead of returning `""`.
- `validate_file_check`, `validate_file_delete` and the scoring equivalents no longer raise an empty message for `{"error": ""}`; an empty `error` is not an error.
- `Zerobounce::Client#inspect` and `Zerobounce::Warmup#inspect` no longer show the API key.

### Changed

- Errors reported on a 2xx response raise `Zerobounce::ApiResponseError` with `#status_code` set to the HTTP status (usually 200). `ApiResponseError` is now a subclass of `RuntimeError` (it was a `StandardError`), so `rescue RuntimeError` catches these errors as before.
- The license file is named `LICENSE` (it was `LICENSE.txt`), and the gem ships only that one license file.
- The gemspec has a fuller summary and description, and `source_code_uri`, `changelog_uri` and `homepage_uri` metadata.
- Development only (nothing ships to gem users): `benchmark` is a development dependency, because it left Ruby 4.0's default gems and RuboCop needs it.

### Removed

- `Zerobounce::MockRequest` and the `TEST=unit` switch are gone. With `TEST=unit` set in the environment, the gem routed every call through `MockRequest`, which still called the API but skipped the newer response checks in `Request` (HTML pages, empty bodies, `"success": false`, message-only bodies), so an application's own test or CI setup could get different results from production. Nothing in the gem's specs used it.

## [2.2.0] - 2026-11-11

### Breaking

These change behaviour that 2.1.8 callers can rely on. Check each before upgrading.

- **Breaking:** Ruby 3.0 or later is required (`required_ruby_version` was `>= 2.5`, which CI never tested). On Ruby 2.5 to 2.7 the `Zerobounce::Warmup` methods that send query parameters (such as `get_sending_account` and `statistics`) and `list_inbox_placement_tests` with filters raise `ArgumentError` (unknown keyword), and on 2.5 and 2.6 a successful `validate_file_get` or `scoring_file_get` download raises `NoMethodError` (`StringIO#set_encoding_by_bom`); the offline spec suite passes on 3.0. Bundler on an older Ruby keeps resolving 2.1.8.
- **Breaking:** the gem no longer loads a `.env` file, and `dotenv` is no longer a runtime dependency. Up to 2.1.8, building the configuration (on the first `Zerobounce.configure`, `Zerobounce.config` or API call) called `Dotenv.load`, which read `.env` from the process's current directory and copied every variable in it that was not already set into `ENV` - not only the `ZEROBOUNCE_*` ones. The `ZEROBOUNCE_*` environment variables are still read. To keep using a `.env` file, add `dotenv` to your own Gemfile and `require 'dotenv/load'` before the gem is first configured.
- **Breaking:** `validate_batch` returns the whole response Hash (`email_batch` and `errors`) instead of the `email_batch` Array, and an error for one address no longer raises: it is listed in `errors`. An account-level error (HTTP 200 with an error for the address `all`, such as an invalid API key or no credits) still raises. Migrate `Zerobounce.validate_batch(emails)` to `Zerobounce.validate_batch(emails)['email_batch']`, and check `['errors']`.
- **Breaking:** `{"success": false}` on an HTTP 200 raises a `RuntimeError` with the API's message instead of being returned as the result. Up to 2.1.8 `validate_file_check`, `validate_file_delete`, `scoring_file_check` and `scoring_file_delete` returned it (the API answers an unknown file id, and for a while a just-uploaded one, that way); code that tested `result['success']` must rescue instead. The main-API calls apply the same rule.
- **Breaking:** `api_root_url` and `bulk_api_root_url` (and `ZEROBOUNCE_API_URL` / `ZEROBOUNCE_BULK_API_URL`) must be `https://` URLs; anything else raises `ArgumentError` before a request is sent. Up to 2.1.8 an `http://` URL (for example a local mock server) was used as given. The new base URLs below have the same rule. Redirects are no longer followed either: a 3xx raises its `RestClient` exception (such as `RestClient::Found`) with the message `ZeroBounce answered with a redirect (HTTP 302), which is not followed`, where 2.1.8 followed a redirect on a `GET` request (and a 303 on any request).

### Added

- `validate` options `timeout` (3-60 seconds), `activity_data`, `verify_plus`, `domain_info`, `greylist_processing`, `callback_url` and `use_post` (form-encoded `POST /validate`). An option left out is not sent; booleans go on the wire as the strings `true`/`false`. `callback_url` is where the greylist retry posts its result, so it is rejected without `greylist_processing`, and when blank, before any request is sent.
- `validate_batch` options `timeout` (10-120 seconds, sent as a JSON string, the only form the API accepts), `activity_data`, and `verify_plus`.
- `score_email` for `GET` and `POST /scoring`.
- Bulk email finder and bulk domain search (`send_email_finder_file`, `send_domain_search_file` and their status, get and delete calls). `has_header_row` is sent when it is false, and a name column of `0` is sent when passed; `domain_column` must be 1 or more, and the email finder needs `first_name_column` or `full_name_column`.
- The list evaluator: `send_list_evaluator_file`, `get_list_evaluator_result` (on the list evaluator's own base URL, with the file id encoded as one path segment and a blank id rejected before sending) and `send_evaluated_file`, which takes the evaluator's file id as a form field.
- Filters: `add_filter`, `list_filters` and `delete_filter`. Their success is a bare `{"Message": "..."}` body and is returned; an invalid or drained key, which they answer with an HTTP 200 and `{"Error": "..."}`, raises.
- S3 and SFTP/FTP jobs on the bulkapi host **without** `/v2`: `list_s3_files`, `validate_s3_file`, `score_s3_file`, `email_finder_s3_file`, `domain_search_s3_file`, `export_s3_file`, `validate_sftp_file`, `score_sftp_file`, `email_finder_sftp_file`, `domain_search_sftp_file` and `export_sftp_file`. Every job requires `file_name` and `return_url` and raises `ArgumentError` without them (the live API rejects such a job, although its docs list `file_name` as optional for `validate_sftp_file`). `validate_s3_file` and `score_s3_file` take `file_name:` and `has_header_row:` (default `false`) as keywords; the other jobs take them as the first two positional arguments. `export_s3_file`'s `export_bucket` is optional (left out, the export goes to the bucket in your ZeroBounce settings), and so is `export_sftp_file`'s `export_path`.
- The Inbox Placement Tester. The API key goes in an `Authorization: Bearer` header, not a query parameter; bodies are camelCase JSON and unset fields are left out; the listing is `GET /tests`, with `page_size` (1-100), `created_after` and `created_before`; `create_inbox_placement_test` checks `name` (at most 64 characters), `test_type` (1, 2 or 3) and `sender_email` (required for type 1) before spending inbox-test credits; and its errors, reported under `detail`, are raised with that text.
- `Zerobounce::Client`, which holds one API key for `validate`, `credits` and `validate_batch` without touching `Zerobounce.config`, so threads can use different keys. For any other call, wrap it in `Zerobounce.with_api_key(key) { ... }`, which sets a key for the current thread only.
- `Configuration` gains `bulk_root_url` (`ZEROBOUNCE_BULK_ROOT_URL`), `list_evaluator_root_url` (`ZEROBOUNCE_LIST_EVALUATOR_URL`) and `inbox_placement_root_url` (`ZEROBOUNCE_INBOX_PLACEMENT_URL`). `bulk_root_url` is the root for the S3 and SFTP/FTP jobs; left unset it is derived from `bulk_api_root_url` with the `/v2` stripped. The other two are separate base URLs, so overriding `bulk_api_root_url` alone leaves them pointing at the live API.
- `Zerobounce::ValidateSubStatus::AI_AGENT_MAILBOX` (`ai_agent_mailbox`).
- `Zerobounce::Warmup`, a client for the Warmup API. It is a separate product with its own host (`https://warmup-api.zerobounce.net`), its own team-scoped key sent in an `API-Key` header, and all 26 documented endpoints, including the seed-list and statistics CSV downloads.
- `Zerobounce::ApiResponseError`, which carries the HTTP status through `#status_code`. The Warmup client raises it.
- An opt-in live API suite (`ruby -Ilib live/live_api.rb`). It lives outside `spec/`, so `rspec` and CI never load it. Its default tier makes only free calls and submits no job; it spends credits or submits jobs only with `ZEROBOUNCE_LIVE_SPEND=1`, and changes the account only with `ZEROBOUNCE_LIVE_CHANGES=1`.

### Changed

- An HTTP error status still raises the `RestClient` exception for that status (`RestClient::NotFound` and so on, with `#http_code` and `#response`), but its message is now the API's short error text, for example `File not found`, instead of RestClient's status line (`404 Not Found`). An HTML error page becomes a one-line message naming its title.
- Error messages taken from the API have a repeated `Error:` / `[Error]:` prefix removed.
- `find_email`'s `first_name` is optional: without a name the API answers with the domain's format. It is still the first positional argument, so existing calls are unchanged.
- API requests time out after 120 seconds (connect and read; up to 2.1.8 Net::HTTP's 60-second defaults applied).
- Validation-client requests send `User-Agent: ZerobounceRubyGem/2.2.0`, the value of `Configuration#headers[:user_agent]`. Up to 2.1.8 that value was set but never sent, and requests carried RestClient's default user agent.
- The packaged gem contains only `lib/`, `README.md`, the licence files and `CHANGELOG.md`. Up to 2.1.8 it packaged every git-tracked file outside `spec/`, including the CI workflows, `Dockerfile`, the sample CSVs and `documentation.md`.

### Fixed

- `validate_file_check`, `validate_file_delete`, `scoring_file_check` and `scoring_file_delete` returned the raw body as a `String` when the API typed its JSON `application/json; charset=utf-8`, because the content type was compared with `==`; an `{"error": ...}` payload then read as a success. The media type is now matched on its own, ignoring the parameters after the semicolon, on every call.
- An HTML page served with HTTP 200 (such as a Cloudflare "Access denied" page) raises a short error. Up to 2.1.8 it came back as the result: a raw `RestClient::Response` from the main-API `GET` calls, and the page text from the bulk status and delete calls and from `validate_file_get` and `scoring_file_get`.
- An empty or non-JSON body raises a short error, instead of a `JSON::ParserError` or the raw response.
- An empty or blank API key is rejected before a request is sent; up to 2.1.8 only a missing (`nil`) key was.

### Security

- Redirects are not followed, so a 3xx response cannot send the API key to another host.
- Error messages are redacted of the API key the request used - the global one, a `Zerobounce::Client`'s, or one set with `with_api_key` - in plain and URL-encoded form. A low-level error (an unparseable URL quotes the whole query string, key included) is re-raised with the redacted message and without the original attached as `#cause`, which `#full_message` would otherwise print. The `RestClient` exception for an HTTP error status still holds the request, URL included, in `#response`, as it did up to 2.1.8; do not log that object.
- `Zerobounce::Configuration#inspect` shows `[FILTERED]` in place of the API key.
- A Warmup API key with surrounding whitespace or control characters is rejected, because the transport would otherwise quote it unredacted in its own error; a Warmup base URL must be `https://`; and the Warmup SMTP test masks the username and password out of every error it raises.

## [2.1.8] - 2026-08-14

### Fixed

- `Gemfile.lock` matches the gemspec version, so a frozen install can resolve the gem.

## [2.1.6] - 2026-06-18

### Fixed

- `validate_batch` posts to `api.zerobounce.net` instead of `bulkapi.zerobounce.net`.

## [2.1.5] - 2026-06-10

### Added

- `catchall_domain` on validation results.

## [2.1.1] - 2026-04-08

### Security

- Development and transitive dependency floors were raised for REXML, Addressable, and YARD.

## [2.1.0] - 2026-04-08

### Added

- Optional bulk get-file parameters, including download type and activity data.

## [2.0.12] - 2026-03-03

### Changed

- License the project under MIT.

## [2.0.1] - 2026-03-03

### Security

- Uploaded file paths must stay under the current directory.

## [2.0.0] - 2026-03-03

### Changed

- Release the 2.0 line of the gem.

## [1.3.0] - 2025-10-22

### Added

- `find_email` and `find_domain`.

### Deprecated

- `guessformat`. Use `find_email` or `find_domain`.

## [0.3.0] - 2023-09-18

### Changed

- Ruby and Bundler version requirements.

## [0.2.0] - 2023-09-12

### Changed

- Faraday requirements, and the minimum Ruby version is 2.5.

## [0.1.2] - 2023-04-18

### Fixed

- Error-body detection no longer depends on a quote immediately after the colon.

## [0.1.1] - 2023-04-12

### Fixed

- Removed safe-navigation calls so the client runs on older Ruby.

## [0.1.0] - 2023-04-07

### Added

- Initial client for ZeroBounce API v2.

[Unreleased]: https://github.com/zerobounce/zero-bounce-ruby/compare/v3.0.1...HEAD
[3.0.1]: https://github.com/zerobounce/zero-bounce-ruby/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.2.0...v3.0.0
[2.2.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.8...v2.2.0
[2.1.8]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.6...v2.1.8
[2.1.6]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.5...v2.1.6
[2.1.5]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.1...v2.1.5
[2.1.1]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.12...v2.1.0
[2.0.12]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.1...v2.0.12
[2.0.1]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/zerobounce/zero-bounce-ruby/releases/tag/v1.3.0
