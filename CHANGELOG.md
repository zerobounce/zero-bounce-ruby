# Unreleased

* `validate` accepts `domain_info`, `greylist_processing` and `callback_url`. An option left out is not sent; booleans go on the wire as the strings `true`/`false`. `callback_url` is where the greylist retry posts its result, so it is rejected without `greylist_processing`, and when blank, before any request is sent.
* Add the rest of the documented bulk surface: `email_finder_s3_file`, `domain_search_s3_file`, and the SFTP/FTP jobs `validate_sftp_file`, `score_sftp_file`, `email_finder_sftp_file`, `domain_search_sftp_file` and `export_sftp_file`. These are on the bulkapi host **without** `/v2`. `validate_sftp_file`'s file name is optional - passing `nil` uses the input bucket from your ZeroBounce settings - and `export_sftp_file` takes `export_path`, not the `export_bucket` `export_s3_file` sends.
* Add the Inbox Placement Tester: the API key goes on the query string, bodies are camelCase JSON, and unset fields are left out.
* `Configuration` gains `bulk_root_url`, `list_evaluator_root_url` and `inbox_placement_root_url`. These are separate base URLs rather than paths built from `bulk_api_root_url`, so overriding that alone leaves them pointing at the live API.
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

### Changed

- `validate_batch` returns the full response hash (`email_batch` and `errors`). A per-address error stays on that hash.
- API requests time out after 120 seconds and do not follow redirects.
- Multipart booleans are sent as `true` or `false`.

### Fixed

- An HTML "Access denied" page is a short `RuntimeError`. An HTML page with status 200 is an error as well, including `validate_file_get`, instead of file text or a JSON parse.
- Empty and non-JSON bodies are a short error. A repeated `Error:` / `[Error]:` prefix is removed.
- `validate_batch` raises for an account-level failure (HTTP 200, error for address `all`, such as an invalid API key or no credits).
- Bulk email finder and domain search send `has_header_row` when it is false. A column index of `0` is sent when the caller passes it.
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
