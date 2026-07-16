# frozen_string_literal: true

module Quotes
  # Acquires a PostgreSQL advisory lock scoped to a quote to serialize mutations across the
  # whole quote aggregate (quote, quote versions, order forms and orders).
  #
  # The lock is reentrant: cascade calls that re-enter the same quote lock (e.g. approve ->
  # create order form, expire/void -> void version, clone -> void version) yield immediately
  # within the already-held transaction instead of re-acquiring.
  #
  # Usage in jobs:
  #   retry_on Customers::FailedToAcquireLock,
  #            attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay
  #
  class LockService < BaseService
    ACQUIRE_LOCK_TIMEOUT = 5.seconds

    Result = BaseResult

    def initialize(quote:, timeout_seconds: ACQUIRE_LOCK_TIMEOUT, transaction: true)
      @quote = quote
      @timeout_seconds = timeout_seconds
      @transaction = transaction

      super
    end

    def call
      Quote.with_advisory_lock!(lock_key, timeout_seconds:, transaction:) do
        yield
      end
    rescue WithAdvisoryLock::FailedToAcquireLock
      raise Customers::FailedToAcquireLock, "Failed to acquire lock #{lock_key}"
    end

    private

    attr_reader :quote, :timeout_seconds, :transaction

    def lock_key
      "quote-#{quote.id}"
    end
  end
end
