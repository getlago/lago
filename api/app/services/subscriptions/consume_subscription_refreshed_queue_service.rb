# frozen_string_literal: true

module Subscriptions
  class ConsumeSubscriptionRefreshedQueueService < BaseService
    Result = BaseResult

    REDIS_STORE_NAME = "subscription_refreshed_v2"
    BATCH_SIZE = 100
    PROCESSING_TIMEOUT = 1.minute

    # Events-processor writes to a sorted set with ZADD, using the event timestamp as score
    # and a bucketed member key (org_id:sub_id|bucket). Members are only eligible for consumption
    # once their score has aged past SUBSCRIPTION_BUCKET_DURATION.
    SUBSCRIPTION_BUCKET_DURATION = 10

    def call
      return result if ENV["LAGO_REDIS_STORE_URL"].blank?

      start_time = Time.current

      loop do
        if Time.current - start_time > PROCESSING_TIMEOUT
          break
        end

        threshold = (Time.current - SUBSCRIPTION_BUCKET_DURATION).to_i
        values = redis_client.zrangebyscore(REDIS_STORE_NAME, "-inf", threshold, limit: [0, BATCH_SIZE])
        break if values.blank?

        values.each do |value|
          # Extract the subscription_id from the bucketed member key (org_id:sub_id|bucket)
          subscription_id = value.split("|").first.split(":").last

          Subscriptions::FlagRefreshedJob.perform_later(subscription_id)
        end

        redis_client.zrem(REDIS_STORE_NAME, values)
      end

      result
    end

    private

    def redis_client
      return @redis_client if defined? @redis_client

      url = if ENV["LAGO_REDIS_STORE_URL"].start_with?(/rediss?:\/\//)
        ENV["LAGO_REDIS_STORE_URL"]
      else
        "redis://#{ENV["LAGO_REDIS_STORE_URL"]}"
      end

      config = {
        url:,
        timeout: 5.0,
        reconnect_attempts: 3
      }

      config[:password] = ENV["LAGO_REDIS_STORE_PASSWORD"] if ENV["LAGO_REDIS_STORE_PASSWORD"].present?
      config[:db] = ENV["LAGO_REDIS_STORE_DB"] if ENV["LAGO_REDIS_STORE_DB"].present?

      if ENV["LAGO_REDIS_STORE_SSL"].present? || ENV["LAGO_REDIS_STORE_URL"].start_with?("rediss:")
        config[:ssl] = true
      end

      if ENV["LAGO_REDIS_STORE_DISABLE_SSL_VERIFY"].present?
        config[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE}
      end

      @redis_client ||= Redis.new(config)
    end
  end
end
