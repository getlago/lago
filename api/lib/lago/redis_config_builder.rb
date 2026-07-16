# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "lago/redis_loading_retry_middleware"

module Lago
  # Builds a Redis configuration hash from environment variables.
  #
  # Base config for `#sidekiq` includes URL (REDIS_URL), SSL params, password
  # (REDIS_PASSWORD), and optional Sentinel support
  # (LAGO_REDIS_SIDEKIQ_SENTINELS, LAGO_REDIS_SIDEKIQ_MASTER_NAME).
  #
  # LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS (default: 5) defines a retry window (in seconds).
  # The window is turned into a series of quadratically increasing retry intervals
  # (0.1, 0.4, 0.9, ...) whose total stays within the window. Each interval is
  # jittered by +-25% so processes don't retry in lockstep. The same schedule is
  # used both for `reconnect_attempts` (connection retry) and for
  # `RedisLoadingRetryMiddleware`, wired in via `middlewares`, with its schedule
  # passed through `custom[:loading_retry_attempts]` (LOADING command retry while
  # a node loads its dataset).
  #
  # Base config for `#cache` includes URL (LAGO_REDIS_CACHE_URL), SSL params,
  # password (LAGO_REDIS_CACHE_PASSWORD), and optional Sentinel support
  # (LAGO_REDIS_CACHE_SENTINELS, LAGO_REDIS_CACHE_MASTER_NAME).
  #
  # Use `with_options` to merge consumer-specific options before calling
  # either method.
  #
  # @example Sidekiq initializer
  #   Lago::RedisConfigBuilder.new
  #     .with_options(pool_timeout: 5)
  #     .sidekiq
  #
  # @example ActiveJob uniqueness initializer
  #   Lago::RedisConfigBuilder.new
  #     .sidekiq
  #
  # @example Cache initializer
  #   Lago::RedisConfigBuilder.new
  #     .with_options(pool: {size: 5})
  #     .cache
  class RedisConfigBuilder
    def initialize
      @extra_options = {}
    end

    def with_options(options)
      @extra_options = extra_options.merge!(options)
      self
    end

    def sidekiq
      redis_config = {
        url: ENV["REDIS_URL"].presence,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        },
        timeout: 1
      }.compact

      add_sentinels(
        redis_config,
        sentinels: ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"].presence,
        master_name: ENV.fetch("LAGO_REDIS_SIDEKIQ_MASTER_NAME", "master").presence
      )
      add_password(redis_config, password: ENV["REDIS_PASSWORD"].presence)
      add_retries(redis_config, window: sidekiq_retry_window_seconds)

      redis_config.merge(extra_options)
    end

    def cache
      redis_config = {
        url: ENV["LAGO_REDIS_CACHE_URL"].presence,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        },
        timeout: 1
      }.compact

      add_sentinels(
        redis_config,
        sentinels: ENV["LAGO_REDIS_CACHE_SENTINELS"].presence,
        master_name: ENV.fetch("LAGO_REDIS_CACHE_MASTER_NAME", "master").presence
      )
      add_password(redis_config, password: ENV["LAGO_REDIS_CACHE_PASSWORD"].presence)
      # The cache deliberately skips retry wiring (no `reconnect_attempts` or
      # `RedisLoadingRetryMiddleware`): cache reads/writes fail fast so callers degrade
      # gracefully, rather than blocking on retries while a node fails over or reloads.

      redis_config.merge(extra_options)
    end

    def self.cache_enabled?
      ENV["LAGO_REDIS_CACHE_URL"].present? || ENV["LAGO_REDIS_CACHE_SENTINELS"].present?
    end

    private

    attr_reader :extra_options

    DEFAULT_SIDEKIQ_RETRY_WINDOW_SECONDS = 5
    private_constant :DEFAULT_SIDEKIQ_RETRY_WINDOW_SECONDS

    def sidekiq_retry_window_seconds
      ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"].presence || DEFAULT_SIDEKIQ_RETRY_WINDOW_SECONDS
    end

    def add_sentinels(config, sentinels:, master_name:)
      return unless sentinels

      config[:sentinels] = parse_sentinels(sentinels)
      config[:role] = :master
      config[:name] = master_name.presence || "master"
    end

    def add_password(config, password:)
      return unless password

      config[:password] = password
    end

    # Wires both retry mechanisms off the same window: `reconnect_attempts` for
    # connection drops, and `RedisLoadingRetryMiddleware` (with its schedule in
    # `custom[:loading_retry_attempts]`) for LOADING command errors.
    def add_retries(config, window:)
      return unless window

      intervals = build_retry_intervals(window)
      config[:reconnect_attempts] = intervals
      config[:middlewares] = [RedisLoadingRetryMiddleware]
      config[:custom] = {loading_retry_attempts: intervals}
    end

    # Builds quadratically increasing retry intervals (0.1, 0.4, 0.9, 1.6, ...)
    # whose cumulative sum stays within the given window (in seconds). Each
    # interval is jittered by +-25% at boot, so concurrent processes spread
    # their retries instead of hammering Redis in lockstep.
    # Computed in tenths of a second to avoid float precision drift.
    def build_retry_intervals(window)
      window_tenths = (parse_window(window) * 10).floor
      intervals = []
      attempt = 1
      total_tenths = 0

      loop do
        interval_tenths = jitter(attempt**2)
        break if total_tenths + interval_tenths > window_tenths

        intervals << interval_tenths / 10.0
        total_tenths += interval_tenths
        attempt += 1
      end

      intervals
    end

    def jitter(tenths)
      (tenths * rand(0.75..1.25)).round.clamp(1..)
    end

    def parse_window(window)
      Float(window)
    rescue ArgumentError
      raise ArgumentError, "Invalid Redis retry attempts window #{window.inspect}, expected a number of seconds"
    end

    def parse_sentinels(sentinels)
      sentinels.split(",").map do |sentinel|
        host, port = sentinel.split(":")
        host = host&.strip
        port = port&.strip
        config = {host:}
        if port.present?
          begin
            config[:port] = Integer(port)
          rescue ArgumentError
            raise ArgumentError, "Invalid Redis sentinel port #{port.inspect} in #{sentinel.inspect}"
          end
        end
        config
      end
    end
  end
end
