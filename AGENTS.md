# Agent notes — zero-bounce-ruby

## Layout

- `lib/zerobounce.rb`: every public method, as module functions on `Zerobounce`. The Priority 3 endpoints live in `lib/zerobounce/priority3.rb`.
- `lib/zerobounce/base_request.rb`: the HTTP layer. `_get` / `_post` are the originals; `_execute` is the one that takes an explicit method and either a form or a JSON body, which the bulk jobs and the Inbox Placement Tester's PUT and DELETE need. `root_request` and `ipt_request` are public and shared by both `Request` and `MockRequest`.
- `lib/zerobounce/configuration.rb`: four base URLs, see below.
- `lib/zerobounce/warmup.rb`: a separate client for the Warmup API, a different product with its own host and its own team-scoped key. It is `Zerobounce::Warmup`, not part of the `Zerobounce` module functions.
- `spec/offline_api_spec.rb`, `spec/warmup_spec.rb`: the offline suites, stubbed with WebMock.
- `live/live_api.rb`: the opt-in live suite. It sits outside `spec/`, so `rspec` and CI never load it.

## Build and test

The base branch is **`develop`**, not `main`/`master`.

Ruby runs in Docker (the host gems are not installed):

```sh
cd ../sdk-docs && docker compose run --rm --build ruby
```

To run against the working tree without rebuilding:

```sh
docker run --rm -u 0 -v "$PWD":/src -w /src zerobounce-sdk-ruby:test \
  sh -c "bundle _2.4.22_ config set --local path /app/vendor/bundle && bundle _2.4.22_ exec rspec"
```

The live suite is run by hand, never by rspec:

```sh
export ZEROBOUNCE_API_KEY=... ZEROBOUNCE_WARMUP_API_KEY=...
ruby -Ilib live/live_api.rb                                   # free calls only
ZEROBOUNCE_LIVE_SPEND=1 ruby -Ilib live/live_api.rb
ZEROBOUNCE_LIVE_CHANGES=1 ruby -Ilib live/live_api.rb
```

Keys come from the environment only. Never write one into a file, a commit, a
log, a fixture or a message.

CI runs `bundle exec rspec` only. `rake default` also runs RuboCop, which reports a large number of pre-existing offences across the repo and is **not** a gate — do not treat its output as a regression from your change.

## Rules

- **Only endpoints documented at https://www.zerobounce.net/docs/.** Do not add a method for an endpoint the public docs do not describe, even if it exists on the server. Check before concluding something is undocumented: the S3 and SFTP bulk endpoints live under https://www.zerobounce.net/docs/api-integrations, not the main API reference.
- **Four base URLs.** `api_root_url`, `bulk_api_root_url` (ends in `/v2/`), `bulk_root_url` (the S3/SFTP jobs, **no** `/v2`), and `list_evaluator_root_url` / `inbox_placement_root_url`. The last three are separate values rather than paths built from `bulk_api_root_url`, so overriding that alone leaves a test pointing at the live API.
- **Where the live API and the docs disagree, follow the API and say so in a comment at the call site.** The ones found so far: `validatebatch` takes `timeout` as a JSON *string*; the Inbox Placement Tester authenticates with `Authorization: Bearer`, not `api_key`; its listing is `GET /tests`, not `/test`; `send-evaluated-file` takes `file_id` as a form field, not a file upload; the S3 and SFTP jobs require `return_url` and `file_name`, `validate_sftp_file` included; `/filters/*` answers a *success* with a bare `{"Message": ...}` body; the Warmup `check-domain-dmarc` takes an email address, not a domain; and a failed SMTP login in `test-smtp-configuration` comes back as an HTTP 500.
- **`export_sftp_file` sends `export_path`**, not the `export_bucket` that `export_s3_file` sends.
- **`{"success": false}` on an HTTP 200 is a failure.** The API answers an unknown bulk file id that way; both `bulk_get` and `__parse_json_response__` raise on it.
- **A body that is nothing but `Message` means different things per endpoint.** On the validate endpoints it is a rejection; on `/filters/add`, `/filters/delete` and `/filters/list` it is the success. `Request::FILTER_PATHS` is the exception list.
- **`Gemfile.lock` pins the gem's own version.** A version bump must update both `lib/zerobounce/version.rb` and `Gemfile.lock`, or `bundle install --deployment` in CI fails.
- **Offline tests only, in `spec/`.** Never call the live API from a spec. The live suite is the separate, opt-in `live/live_api.rb`.
- **Errors carry the HTTP status.** The Warmup client raises `Zerobounce::ApiResponseError`, whose `#status_code` lets callers tell a Cloudflare 403 from an API 400/404 and a Warmup 429. The validation client still raises a `RuntimeError` with the same short message.

## Releasing

**Run the live suite by hand before every release.** The offline suite proves the SDK sends what we think it sends; only the live suite proves the API accepts it. Run it with real keys, including `ZEROBOUNCE_LIVE_SPEND=1` and `ZEROBOUNCE_LIVE_CHANGES=1`, and do not release on a failure.
