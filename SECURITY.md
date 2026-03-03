# Security Policy

## Reporting a Vulnerability

If you think you've found a security issue, please report it privately instead of opening a public issue.

**Email:** integrations@zerobounce.net (use a subject like `[zero-bounce-ruby] Security`).

We'll look into reports as we can. If the issue is in the Zero Bounce API or service rather than this SDK, we may forward it to the right team.

## Supported Versions

We focus on the current release line for fixes. Using the [latest version](https://rubygems.org/gems/zerobounce-sdk) is recommended.

## Tips for Using This SDK

* Don't commit API keys or `.env` files—use environment variables or a secrets manager.
* Keep dependencies up to date with `bundle install` and upgrade when new versions are released.
* The client uses HTTPS by default; avoid overriding to non-HTTPS in production.

Thanks for helping keep things secure.
