# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in zerobounce.gemspec
gemspec

# Transitive dependency floors (security advisories: REXML DoS/ReDoS, Addressable ReDoS).
gem 'rexml', '>= 3.4.4'
gem 'addressable', '>= 2.8.10'

