# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.2"

# Core
gem "aasm"
gem "activejob-uniqueness", require: "active_job/uniqueness/sidekiq_patch"
gem "redlock", "~> 2.0.6" # Used through `activejob-uniqueness`. It's pinned to 2.0.x because we patched the library to fix a bug.
gem "active_storage_validations"
gem "bootsnap", require: false
gem "clockwork", require: false
gem "parallel"
gem "puma", "~> 7.2"
gem "rails", "~> 8.0"
gem "redis"
gem "sidekiq"
gem "sidekiq-prometheus-exporter"
group :"sidekiq-pro", optional: true do
  source "https://gems.contribsys.com/" do
    gem "sidekiq-pro"
  end
  gem "dogstatsd-ruby"
end
gem "sidekiq-throttled", "1.4.0" # '1.5.0' was losing some jobs
gem "throttling"
gem "device_detector"
gem "dry-validation"

# Security
gem "bcrypt"
gem "googleauth", "~> 1.16.2"
gem "jwt"
gem "oauth2"
gem "rack-cors"

# Database
gem "after_commit_everywhere"
gem "clickhouse-activerecord", "~> 1.6.1"
gem "discard", "~> 1.2"
gem "kaminari-activerecord"
gem "paper_trail"
gem "pg"
gem "ransack"
gem "scenic"
gem "with_advisory_lock"
gem "strong_migrations"
gem "connection_pool", "<3" # Temporary fix. See https://github.com/mperham/connection_pool/issues/212

# Currencies, Countries, Timezones...
gem "bigdecimal"
gem "countries"
gem "money-rails"
gem "timecop", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# GraphQL
gem "graphql"
gem "graphql-pagination"

# Payment processing
gem "adyen-ruby-api-library"
gem "gocardless_pro", "~> 2.34"
gem "stripe"

# Analytics
gem "analytics-ruby", require: "segment/analytics"

# SSE
gem "event_stream_parser"

# Logging
gem "lograge"
gem "logstash-event"

# HTTP and Multipart support
gem "multipart-post"
gem "mutex_m"

# Monitoring
gem "newrelic_rpm"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-all"
gem "opentelemetry-sdk"
gem "yabeda"
gem "yabeda-rails"
gem "yabeda-puma-plugin"
gem "yabeda-prometheus"

gem "stackprof", require: false, platforms: [:ruby, :mri]
gem "sentry-rails"
gem "sentry-ruby"
gem "sentry-sidekiq"

gem "datadog", require: false

# Storage
gem "aws-sdk-s3", require: false
gem "google-cloud-storage", require: false

# Templating
gem "slim"
gem "slim-rails"
gem "addressing"

# Kafka
gem "karafka", "~> 2.5.0"
gem "karafka-web", "~> 0.11.3"

# Taxes
gem "valvat"

# Data Export
gem "csv", "~> 3.0"
gem "ostruct"

gem "lago-expression", github: "getlago/lago-expression", glob: "expression-ruby/lago-expression.gemspec", ref: "2abd2b3"

group :development, :test, :staging do
  gem "factory_bot_rails"
  gem "faker"
end

group :development, :test do
  gem "bullet"
  gem "clockwork-test"
  gem "debug", platforms: %i[mri windows], require: false
  gem "dotenv"
  gem "fuubar"
  gem "rspec-rails"
  gem "simplecov", require: false
  gem "webmock"
  gem "awesome_print"
  gem "pry-byebug"
  gem "knapsack_pro", "~> 9.0"
  gem "parallel_tests", "~> 5.3"

  gem "database_cleaner-active_record"
  gem "rspec-graphql_matchers"
  gem "shoulda-matchers"

  gem "i18n-tasks", require: false

  gem "rubocop-rails", require: false
  gem "rubocop-graphql", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-thread_safety", require: false

  gem "vernier", "~> 1.10", require: false
  gem "super_diff", "~> 0.18.0"
end

group :test do
  gem "guard-rspec", require: false
  gem "karafka-testing"

  # HTML testing (invoice rendering)
  gem "rspec-snapshot", "~> 2.0"
  gem "htmlbeautifier", "~> 1.4"
end

group :development do
  gem "coffee-rails"
  gem "graphiql-rails"
  gem "httplog"

  gem "standard", require: false
  gem "annotaterb"

  gem "sass-rails"
  gem "uglifier"

  gem "ruby-lsp-rails", require: false
end
