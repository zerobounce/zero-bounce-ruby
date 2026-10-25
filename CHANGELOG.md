# Unreleased

* `validate` accepts `domain_info`, `greylist_processing` and `callback_url`. An option left out is not sent; booleans go on the wire as the strings `true`/`false`. `callback_url` is where the greylist retry posts its result, so it is rejected without `greylist_processing`, and when blank, before any request is sent.
* Add the rest of the documented bulk surface: `email_finder_s3_file`, `domain_search_s3_file`, and the SFTP/FTP jobs `validate_sftp_file`, `score_sftp_file`, `email_finder_sftp_file`, `domain_search_sftp_file` and `export_sftp_file`. These are on the bulkapi host **without** `/v2`. `validate_sftp_file`'s file name is optional - passing `nil` uses the input bucket from your ZeroBounce settings - and `export_sftp_file` takes `export_path`, not the `export_bucket` `export_s3_file` sends.
* Add the Inbox Placement Tester: the API key goes on the query string, bodies are camelCase JSON, and unset fields are left out.
* `Configuration` gains `bulk_root_url`, `list_evaluator_root_url` and `inbox_placement_root_url`. `list_evaluator_root_url` and `inbox_placement_root_url` are separate base URLs rather than paths built from `bulk_api_root_url`, so overriding that alone leaves them pointing at the live API. `bulk_root_url` (`ZEROBOUNCE_BULK_ROOT_URL`) now actually reaches the request layer: set, it is the root for the S3 and SFTP/FTP jobs; unset, that root is still derived from `bulk_api_root_url` with the `/v2` stripped. It was previously written and never read, so the environment variable looked supported and did nothing.
* `get_list_evaluator_result` uses the list evaluator's own base URL, encodes the file id as a single path segment, and rejects a blank id before a request is sent.
* An error body carrying a `detail` key (the Inbox Placement Tester is a Django REST framework app) is now raised with that text.
* Add `Zerobounce::Warmup`, a client for the Warmup API. It is a separate product with its own host (`https://warmup-api.zerobounce.net`), its own team-scoped key sent in an `API-Key` header, and all 26 documented endpoints, including the seed-list and statistics CSV downloads.
* Add `Zerobounce::ApiResponseError`, which carries the HTTP status through `#status_code`, so callers can tell a Cloudflare 403 from an API 400/404 and a Warmup 429. The Warmup client raises it.
* Add an opt-in live API suite (`ruby -Ilib live/live_api.rb`). It lives outside `spec/`, so `rspec` and CI never load it, and it only spends credits or changes the account behind `ZEROBOUNCE_LIVE_SPEND=1` and `ZEROBOUNCE_LIVE_CHANGES=1`.
* Verified against the live API; where the API and the docs disagree, the API wins:
  * `validate_batch` sends `timeout` as a JSON **string**. Sent as a number the API rejects the whole batch with an account-level error.
  * The Inbox Placement Tester authenticates with an `Authorization: Bearer` header, not an `api_key` parameter, so the key no longer reaches a query string that gets logged. Its listing is `GET /tests`; `/test` answers `Method "GET" not allowed`.
  * `send_evaluated_file` takes the list evaluator's `file_id` as a form field, not a file upload, so its argument is now a file id.
  * The S3 and SFTP jobs require `file_name` and `return_url`, `validate_sftp_file` included, although the docs list `file_name` as optional for that one.
* Fixed: `list_s3_files` asked for `bulkapi/v2/listS3files`. Like every other S3 and SFTP/FTP call it lives on the bulkapi **root**, so the request 404ed.
* Fixed: a response typed `application/json; charset=utf-8` skipped JSON parsing, because the content type was compared with `==` against the bare media type. The raw body came back as a `String`, so an `{"error": ...}` payload read as a success instead of raising. The media type is now matched on its own, ignoring the parameters after the semicolon. Affects the bulk file status, get and delete calls, the AI scoring, email finder and domain search bulk jobs, and `list_s3_files`.
* Fixed: `validate_s3_file` and `score_s3_file` took `return_url` through `**options` and never required it, so the live API rejected the job. They now go through the same helper as the other six S3/SFTP jobs, which requires `file_name` and `return_url` and sends `has_header_row` and `remove_duplicates` in the documented shape. `has_header_row` is now a named keyword and defaults to `false`.
* Fixed: `export_s3_file` demanded `export_bucket`. It is optional - omitted, the export goes to the bucket in your ZeroBounce settings - the way `export_sftp_file`'s `export_path` already was.
* Fixed: `list_inbox_placement_tests` sent `pageSize`, which the API accepts and then ignores; the parameter it honours is `page_size`. It also accepts `created_after` / `created_before` (sent as `createdAfter` / `createdBefore`), and rejects a page size outside 1-100 before a request is sent.
* Fixed: `send_email_finder_file` now requires `first_name_column` or `full_name_column`. With neither, the finder has no name to build a local part from.
* Fixed: `create_inbox_placement_test` checks the documented bounds before spending inbox-test credits: `name` at most 64 characters, `test_type` one of 1, 2 or 3, and `sender_email` required when `test_type` is 1.
* Fixed: `find_email`'s `first_name` is optional. `/guessformat` only requires a domain or a company name; without a name it answers with the domain's format. It is still the first positional argument, so existing calls are unchanged, and `find_domain` and the deprecated `guessformat` keep their own signatures.
* Fixed: `add_filter`, `delete_filter` and `list_filters` raised on success. They answer with a bare `{"Message": "..."}` body, which everywhere else means the request was rejected.
* Fixed: `{"success": false}` on an HTTP 200 raises instead of being returned as a result. The API answers an unknown bulk file id that way.
* Security: a Warmup API key with surrounding whitespace or control characters is rejected, because the transport would otherwise quote it unredacted in its own error; a Warmup base URL must be `https://`; and the Warmup SMTP test masks the username and password out of every error it raises.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `validate` options `timeout`, `activity_data`, `verify_plus`, and `use_post` (form-encoded `POST /validate`).
- `validate_batch` options `timeout`, `activity_data`, and `verify_plus`.
- `score_email` for `GET` and `POST /scoring`.
- Bulk email finder, bulk domain search, list evaluator, filters, and S3 (`validate_s3_file`, `score_s3_file`, `export_s3_file`, `list_s3_files`).
- `Zerobounce::Client` so each API key stays on its own thread. Module methods still share `Zerobounce.config`.
- `Configuration#bulk_root_url` / `ZEROBOUNCE_BULK_ROOT_URL` is read by the request layer and overrides the root used by the S3 and SFTP/FTP jobs.

### Changed

- `validate_batch` returns the full response hash (`email_batch` and `errors`). A per-address error stays on that hash.
- API requests time out after 120 seconds and do not follow redirects.
- Multipart booleans are sent as `true` or `false`.

### Fixed

- `Zerobounce::ResponseError` used `loc[1..]` to build a validation-error field name. An endless range needs Ruby 2.6, but the gemspec supports 2.5, where the file is a syntax error and the gem will not load at all. Changed to `loc[1..-1]`.

- An HTML "Access denied" page is a short `RuntimeError`. An HTML page with status 200 is an error as well, including `validate_file_get`, instead of file text or a JSON parse.
- Empty and non-JSON bodies are a short error. A repeated `Error:` / `[Error]:` prefix is removed.
- `validate_batch` raises for an account-level failure (HTTP 200, error for address `all`, such as an invalid API key or no credits).
- Bulk email finder and domain search send `has_header_row` when it is false. A column index of `0` is sent when the caller passes it.
- `list_s3_files` is sent to the bulkapi root instead of `/v2`, where it 404ed.
- A `Content-Type` of `application/json; charset=utf-8` is parsed as JSON, so an error payload raises instead of being returned as a raw `String`.
- `validate_s3_file` and `score_s3_file` require `return_url`, which the live API rejects the job without.
- `export_s3_file`'s `export_bucket` is optional and falls back to the account's settings.
- `list_inbox_placement_tests` sends `page_size` (the API ignores `pageSize`), accepts `created_after` / `created_before`, and bounds the page size to 1-100.
- `send_email_finder_file` requires `first_name_column` or `full_name_column`.
- `create_inbox_placement_test` enforces the documented `name`, `test_type` and `sender_email` rules.
- `find_email`'s `first_name` is optional.
- An empty API key is rejected before a request is sent.
- `validate` timeout must be 3–60 seconds. `validate_batch` timeout must be 10–120 seconds.

### Security

- Redirects are disabled, so a 3xx response cannot send the API key to another host.
- Error messages no longer include the raw HTML access-denied page.
- RestClient error text is redacted of the API key.

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

[Unreleased]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.8...HEAD
[2.1.8]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.6...v2.1.8
[2.1.6]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.5...v2.1.6
[2.1.5]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.1...v2.1.5
[2.1.1]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.12...v2.1.0
[2.0.12]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.1...v2.0.12
[2.0.1]: https://github.com/zerobounce/zero-bounce-ruby/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/zerobounce/zero-bounce-ruby/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/zerobounce/zero-bounce-ruby/releases/tag/v1.3.0
