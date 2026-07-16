# frozen_string_literal: true

if ENV["DD_AGENT_HOST"]
  require "lago_utils"
  require "datadog/auto_instrument"

  Datadog.configure do |c|
    c.tracing.instrument :rails
    c.tracing.instrument :sidekiq
    c.tracing.instrument :graphql
    c.tracing.instrument :http
    c.tracing.instrument :pg
    c.tracing.instrument :redis

    c.env = ENV["DD_ENV"] || Rails.env
    c.service = ENV["DD_SERVICE_NAME"] || "lago-api"
    c.version = LagoUtils::Version.call(default: Rails.env).number

    c.tracing.sampling.default_rate = ENV["DD_TRACE_SAMPLE_RATE"]&.to_f || 1.0
  end
end
