# frozen_string_literal: true

require "logger"

module Lago
  # redis-client middleware that retries commands rejected with a LOADING error.
  #
  # Redis replies `LOADING Redis is loading the dataset in memory` while a node
  # warms up after a restart or an ElastiCache failover/upgrade. The socket is
  # healthy, so `reconnect_attempts` does not apply; the command itself has to be
  # retried until the node finishes loading.
  #
  # The retry schedule (backoff intervals in seconds, slept between attempts) is
  # read per-client from redis-client's `custom` config under
  # `:loading_retry_attempts`:
  #
  #   RedisClient.config(
  #     custom: {loading_retry_attempts: [0.1, 0.4, 0.9]},
  #     middlewares: [Lago::RedisLoadingRetryMiddleware]
  #   )
  #
  # `custom` is used (rather than a configured module) because Sidekiq logs the
  # connection options through `Marshal.dump`, which cannot dump an anonymous
  # module but handles a named module and a plain hash. An empty or missing
  # schedule means the LOADING error propagates unchanged.
  #
  # The logger used for the retry warnings is configurable through
  # `Lago::RedisLoadingRetryMiddleware.logger=`. It defaults to `Rails.logger`
  # when Rails is loaded, otherwise a plain stdout logger so the middleware does
  # not depend on a full Rails boot. Warnings are emitted as a hash so loggers
  # backed by a JSON formatter (e.g. Sidekiq's) produce structured output.
  module RedisLoadingRetryMiddleware
    LOADING_CODE = "LOADING"
    private_constant :LOADING_CODE

    # The logger is set once at boot (from an initializer) and only read
    # afterwards, so the shared module state is safe across threads.
    class << self
      attr_writer :logger # rubocop:disable ThreadSafety/ClassAndModuleAttributes

      def logger
        @logger ||= defined?(Rails) ? Rails.logger : Logger.new($stdout) # rubocop:disable ThreadSafety/ClassInstanceVariable
      end
    end

    def call(command, config)
      with_loading_retry(config) { super }
    end

    def call_pipelined(commands, config)
      with_loading_retry(config) { super }
    end

    private

    def with_loading_retry(config)
      attempts = config.custom[:loading_retry_attempts] || []
      attempt = 0

      begin
        yield
      rescue RedisClient::CommandError => e
        raise unless e.code == LOADING_CODE
        raise if attempt >= attempts.size

        interval = attempts[attempt]
        RedisLoadingRetryMiddleware.logger.warn(
          message: "Redis replied LOADING, retrying",
          interval_seconds: interval,
          attempt: attempt + 1,
          attempts: attempts.size
        )
        sleep(interval)
        attempt += 1
        retry
      end
    end
  end
end
