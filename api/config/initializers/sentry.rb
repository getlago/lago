# frozen_string_literal: true

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.release = LagoUtils::Version.call(default: Rails.env).number
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    config.traces_sample_rate = 0
    config.traces_sample_rate = ENV["SENTRY_TRACES_SAMPLE_RATE"].to_f
    config.environment = ENV["SENTRY_ENVIRONMENT"] || Rails.env
  end
end
