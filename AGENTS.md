# Agent notes — zero-bounce-ruby

## Layout

- `lib/zerobounce.rb`: every public method, as module functions on `Zerobounce`. The Priority 3 endpoints live in `lib/zerobounce/priority3.rb`.
- `lib/zerobounce/base_request.rb`: the HTTP layer. `_get` / `_post` are the originals; `_execute` is the one that takes an explicit method and either a form or a JSON body, which the bulk jobs and the Inbox Placement Tester's PUT and DELETE need. `root_request` and `ipt_request` are public and shared by both `Request` and `MockRequest`.
- `lib/zerobounce/configuration.rb`: four base URLs, see below.
- `spec/offline_api_spec.rb`: the offline suite, stubbed with WebMock.

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

CI runs `bundle exec rspec` only. `rake default` also runs RuboCop, which reports a large number of pre-existing offences across the repo and is **not** a gate — do not treat its output as a regression from your change.

## Rules

- **Only endpoints documented at https://www.zerobounce.net/docs/.** Do not add a method for an endpoint the public docs do not describe, even if it exists on the server. Check before concluding something is undocumented: the S3 and SFTP bulk endpoints live under https://www.zerobounce.net/docs/api-integrations, not the main API reference.
- **Four base URLs.** `api_root_url`, `bulk_api_root_url` (ends in `/v2/`), `bulk_root_url` (the S3/SFTP jobs, **no** `/v2`), and `list_evaluator_root_url` / `inbox_placement_root_url`. The last three are separate values rather than paths built from `bulk_api_root_url`, so overriding that alone leaves a test pointing at the live API.
- **Two bulk shapes are easy to get wrong.** `validate_sftp_file`'s file name is optional — `nil` uses the input bucket from the account's settings, and every other job requires it. `export_sftp_file` sends `export_path`, not the `export_bucket` that `export_s3_file` sends.
- **`Gemfile.lock` pins the gem's own version.** A version bump must update both `lib/zerobounce/version.rb` and `Gemfile.lock`, or `bundle install --deployment` in CI fails.
- **Offline tests only.** Never call the live API from a spec.
