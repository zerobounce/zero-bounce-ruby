# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

`zero-bounce-ruby` publishes the `zerobounce-sdk` gem. Callers set `Zerobounce.config.apikey`, or construct `Zerobounce::Client.new(api_key)`. Module methods share one configuration object. A `Client` stores the key on the current thread for the duration of each call.

## Layout

- `lib/zerobounce.rb`: public methods for validate, credits, batch, files, scoring, and finder.
- `lib/zerobounce/priority3.rb`: bulk email finder, domain search, list evaluator, filters, and S3.
- `lib/zerobounce/base_request.rb` and `request.rb`: RestClient transport. `response_error.rb` turns HTML, empty bodies, and non-JSON into a short `RuntimeError`.
- `lib/zerobounce/version.rb`: `Zerobounce::VERSION`. `Gemfile.lock` pins `zerobounce-sdk (X.Y.Z)` to that same version.
- `spec/offline_api_spec.rb`: offline suite. WebMock answers without the network.
- The user agent is `ZerobounceRubyGem/#{Zerobounce::VERSION}`.

## Commands

```bash
bundle exec rspec
bundle exec rubocop
```

`rspec` is the test command. `rubocop` is the lint step; there is no separate typechecker. CI (`.github/workflows/sdk_ci.yml`) runs both on Ruby 3.2. This checkout may be a newer Ruby where RuboCop cannot load `benchmark`; use 3.2 to lint.

## Conventions

- **One key per caller.** `Zerobounce.config` is process-wide. Do not reuse it across users. Use `Zerobounce::Client` (or `with_api_key`) so two threads cannot observe each other's keys. The offline concurrency spec does this.
- **Column indexes.** `0` is a real column. Do not drop it with `if column`. Omit an optional column only when the argument is `nil`. `domain_column` of `0` is rejected. `Import`-style defaults are not used here: the send methods default name columns to 1–4, and an explicit `0` is sent.
- **Optional parameters are omitted when unset.** `timeout`, `activity_data`, `verify_plus`, and `allow_phase_2` are omitted when `nil`. Explicit `false` is sent as `false`.
- **Booleans on multipart are the strings `true` and `false`.** `has_header_row: false` on bulk email finder and domain search is sent. `allow_phase_2` is validation `sendfile` only. `activity_data` on get-file is validation only.
- **`validate` timeout is 3–60 seconds. `validate_batch` timeout is 10–120 seconds.** Out-of-range values raise `ArgumentError` before a request.
- **Failures are `RuntimeError` (or `ArgumentError` for bad arguments).** The message must be short: no raw HTML, no megabyte body, no `JSON::ParserError` dump, and no `Error: Error:` prefix. An account-level `validate_batch` error (`email_address` `all`) raises. A per-address error stays on the returned hash.
- **`validate_batch` returns the hash**, with `email_batch` and `errors`, not only the array.
- **Tests replace HTTP with WebMock.** Do not call the live API from `rspec`.
- Match the surrounding style. Do not reformat unrelated code.

## Changelog

`CHANGELOG.md` follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

- Add every user-visible change to `## [Unreleased]` in the same commit as the change.
- Group entries under these headings, in this order, omitting empty ones: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- Write for SDK users: name the method, option, or behaviour, and say what changed. Leave out CI-only changes, internal refactors, and fixes to code that was never released.
- At 2.y.z, a breaking change bumps the major version, a new method or option bumps the minor version, and fixes alone bump the patch version.

## Releasing

Publishing and pushing tags need a maintainer's explicit approval. Do not bump the version, tag, or publish unless they asked.

1. Move `[Unreleased]` entries under `## [x.y.z] - YYYY-MM-DD`, leave an empty `[Unreleased]` section, and update the compare links at the bottom of `CHANGELOG.md`.
2. Set the same version in `lib/zerobounce/version.rb` and in the `zerobounce-sdk (X.Y.Z)` pin in `Gemfile.lock`. A frozen CI install fails if those two differ. The gemspec reads `Zerobounce::VERSION`; do not add a third copy.
3. `bundle exec rubocop` and `bundle exec rspec`.
4. Tag `vx.y.z` on that commit and run the Publish workflow with that tag. It publishes to RubyGems.
