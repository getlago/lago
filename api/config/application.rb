# frozen_string_literal: true

require_relative "boot"

require "rails/all"
require "ostruct"

Bundler.require(*Rails.groups)

module LagoApi
  class Application < Rails::Application
    config.load_defaults 8.0

    # Disable YJIT as we are not ready yet
    config.yjit = false

    # TODO: Should be turned to false
    config.add_autoload_paths_to_load_path = true
    # config.autoload_lib(ignore: %w[task])
    config.eager_load_paths += %W[
      #{config.root}/lib
      #{config.root}/lib/lago_http_client
      #{config.root}/lib/lago_mcp_client
      #{config.root}/lib/lago_utils
      #{config.root}/lib/lago_eu_vat
      #{config.root}/app/views/helpers
      #{config.root}/app/support
    ]

    config.api_only = true
    config.active_job.queue_adapter = :sidekiq

    # Configuration for active record encryption
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1
    config.active_record.encryption.primary_key = ENV["ENCRYPTION_PRIMARY_KEY"] || ENV["LAGO_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ENCRYPTION_DETERMINISTIC_KEY"] || ENV["LAGO_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ENCRYPTION_KEY_DERIVATION_SALT"] || ENV["LAGO_ENCRYPTION_KEY_DERIVATION_SALT"]
    config.active_record.schema_format = :sql

    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = [
      "--clean",
      "--if-exists",
      "--no-comments",
      "--no-publications",
      "--exclude-table=enriched_events_p*"
    ]

    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]
    config.i18n.available_locales = %i[en fr nb de it es sv pt-BR zh-TW]
    config.i18n.default_locale = :en

    config.generators do |g|
      g.orm(:active_record, primary_key_type: :uuid)
    end

    config.active_support.cache_format_version = 7.1

    config.api_key_cache_ttl = 1.hour
  end
end

require_relative "../lib/active_job/uniqueness/strategies/until_executed_patch"
require_relative "../lib/active_job/logging"
require_relative "../lib/active_job/json_log_subscriber"
