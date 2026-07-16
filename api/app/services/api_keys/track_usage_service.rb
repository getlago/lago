# frozen_string_literal: true

module ApiKeys
  class TrackUsageService < BaseService
    def call
      ApiKey.find_each do |api_key|
        cache_key = "api_key_last_used_#{api_key.id}"
        last_used_at = Rails.cache.read(cache_key)

        next unless last_used_at

        api_key.update_columns(last_used_at:) # rubocop:disable Rails/SkipsModelValidations
        Rails.cache.delete(cache_key)
      end
    end
  end
end
