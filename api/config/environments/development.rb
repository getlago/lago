# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require "lago/redis_config_builder"

Rails.application.configure do
  config.after_initialize do
    Bullet.enable = true
    Bullet.rails_logger = true
  end

  config.autoload_paths += %W[
    #{config.root}/dev
  ]

  # Settings specified here will take precedence over those in config/application.rb.
  config.middleware.use(ActionDispatch::Cookies)
  config.middleware.use(ActionDispatch::Session::CookieStore, key: "_lago_dev")
  config.middleware.use(Rack::MethodOverride)

  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.allowed_request_origins = [ENV["LAGO_API_URL"]]

  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  cache_store_config = Lago::RedisConfigBuilder.new
    .with_options(db: ENV.fetch("LAGO_REDIS_CACHE_DB", 0))
    .cache
  config.cache_store = :redis_cache_store, cache_store_config

  config.action_controller.perform_caching = false

  config.active_storage.service = if ENV["LAGO_USE_AWS_S3"].present? && ENV["LAGO_USE_AWS_S3"] == "true"
    if ENV["LAGO_AWS_S3_ENDPOINT"].present?
      :amazon_compatible_endpoint
    else
      :amazon
    end
  else
    :local
  end

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_job.verbose_enqueue_logs = true

  config.logger = ActiveSupport::Logger.new($stdout)
    .tap { |logger| logger.formatter = ::Logger::Formatter.new }

  config.action_view.annotate_rendered_view_with_filenames = true
  config.action_controller.raise_on_missing_callback_actions = true

  config.hosts << "api.lago.dev"
  config.hosts << "api"

  config.license_url = ENV.fetch("LAGO_LICENSE_URL", "http://license:3000")
  config.api_key_cache_ttl = 10.seconds

  config.action_mailer.perform_caching = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "mailhog",
    port: 1025
  }
  config.action_mailer.preview_paths << Rails.root.join("spec/mailers/previews").to_s

  Dotenv.load
end
