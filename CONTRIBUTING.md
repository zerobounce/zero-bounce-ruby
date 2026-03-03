# Contributing to Zero Bounce Ruby SDK

Thank you for your interest in contributing. This document explains how to get set up, run tests, and submit changes.

## Code of Conduct

By participating in this project, you agree to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

* Ruby 3.2+ (see [.ruby-version](.ruby-version))
* [Bundler](https://bundler.io/) ~> 2.4

### Setup

```bash
git clone https://github.com/zerobounce/zero-bounce-ruby.git
cd zero-bounce-ruby
bundle install
```

### Running Tests

Tests use [RSpec](https://rspec.info/) with [VCR](https://github.com/vcr/vcr) for recorded HTTP interactions. Use the placeholder key so cassettes match:

```bash
ZEROBOUNCE_API_KEY=vcr_test_key bundle exec rspec
```

Or copy `.env.example` to `.env`, set `ZEROBOUNCE_API_KEY=vcr_test_key`, then:

```bash
bundle exec rspec
```

**With Docker:**

```bash
docker build -t zerobounce-ruby-test .
docker run --rm zerobounce-ruby-test
```

### Code Style

The project uses [RuboCop](https://github.com/rubocop/rubocop). Run before submitting:

```bash
bundle exec rubocop
```

## How to Contribute

### Reporting Bugs

Open an [issue](https://github.com/zerobounce/zero-bounce-ruby/issues) and include:

* Ruby version (`ruby -v`)
* Steps to reproduce
* Expected vs actual behavior
* Relevant code or error messages

### Suggesting Changes

* Check existing issues and pull requests first.
* Open an issue to discuss larger changes or API design before coding.

### Submitting Changes

1. **Fork** the repository and create a branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and add or update tests where relevant.

3. **Run the suite** and RuboCop:
   ```bash
   ZEROBOUNCE_API_KEY=vcr_test_key bundle exec rspec
   bundle exec rubocop
   ```

4. **Commit** with a clear message (e.g. `Add X`, `Fix Y`).

5. **Push** your branch and open a **Pull Request** against `main`.

6. In the PR description, briefly explain what changed and why. Link any related issues.

Maintainers will review and may request changes. Once approved, your PR can be merged.

## Project Layout

* `lib/` – SDK source (entry point: `lib/zerobounce.rb`)
* `spec/` – RSpec tests and VCR cassettes (`spec/cassettes/`)
* `data/` – Sample CSV files for batch validation and scoring examples

## Re-recording VCR Cassettes

If you change or add API calls and need to re-record cassettes:

1. Use a valid Zero Bounce API key (e.g. from [dashboard](https://www.zerobounce.net/docs/api-dashboard)).
2. Set `ZEROBOUNCE_API_KEY` and run the specs; VCR will record new HTTP interactions.
3. Replace any real API key in the new cassette files with `vcr_test_key` before committing, so the repo never contains real credentials.

## Questions

* [Zero Bounce API docs](https://www.zerobounce.net/docs/)
* [Project homepage](https://zerobounce.net)
* Contact: **integrations@zerobounce.net**

Thanks for contributing.
