# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require "opentelemetry/sdk"
require "lago/redis_config_builder"

Rails.application.configure do
  # Used for GraphiQL
  config.middleware.use(ActionDispatch::Cookies)
  config.middleware.use(ActionDispatch::Session::CookieStore, key: "_lago_staging")
  config.middleware.use(Rack::MethodOverride)

  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.active_storage.service = if ENV["LAGO_USE_AWS_S3"].present?
    if ENV["LAGO_AWS_S3_ENDPOINT"].present?
      :amazon_compatible_endpoint
    else
      :amazon
    end
  else
    :local
  end

  config.log_level = if ENV["LAGO_LOG_LEVEL"].present? && ENV["LAGO_LOG_LEVEL"] != ""
    ENV["LAGO_LOG_LEVEL"].downcase.to_sym
  else
    :info
  end

  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.allowed_request_origins = [ENV["LAGO_API_URL"]]

  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::Logger.new($stdout)
      .tap { |logger| logger.formatter = ::Logger::Formatter.new }
  end

  config.active_record.dump_schema_after_migration = false

  config.license_url = "http://license-staging-web.default.svc.cluster.local"

  if ENV["LAGO_MEMCACHE_SERVERS"].present?
    config.cache_store = :mem_cache_store, ENV["LAGO_MEMCACHE_SERVERS"].split(",")

  elsif Lago::RedisConfigBuilder.cache_enabled?
    cache_store_config = Lago::RedisConfigBuilder.new
      .with_options(
        pool: {size: ENV.fetch("LAGO_REDIS_CACHE_POOL_SIZE", 5)},
        error_handler: lambda { |method:, returning:, exception:|
          Rails.logger.warn(exception.message)

          Sentry.capture_exception(exception, level: :warning)
        }
      )
      .cache

    config.cache_store = :redis_cache_store, cache_store_config
  end

  if ENV["LAGO_SMTP_ADDRESS"].present? && !ENV["LAGO_SMTP_ADDRESS"].empty?
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["LAGO_SMTP_ADDRESS"],
      port: ENV["LAGO_SMTP_PORT"]
    }
  end

  OpenTelemetry::SDK.configure(&:use_all) if ENV["OTEL_EXPORTER"].present?
end
