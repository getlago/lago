# frozen_string_literal: true

module Customers
  # Acquires a PostgreSQL advisory lock scoped to a customer to prevent concurrent operations.
  #
  # Usage in jobs:
  #   retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError,
  #            attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay
  #
  # - FailedToAcquireLock: Raised when the advisory lock cannot be acquired within the timeout.
  # - StaleObjectError: Even with the advisory lock, other code paths (e.g., wallet top-ups via
  #   IncreaseService) can update wallets without acquiring this lock. Since Wallet uses optimistic
  #   locking (lock_version), concurrent updates will raise StaleObjectError.
  #
  class LockService < BaseService
    ACQUIRE_LOCK_TIMEOUT = 5.seconds
    VALID_SCOPES = %i[prepaid_credit].freeze

    Result = BaseResult

    def initialize(customer:, scope:, timeout_seconds: ACQUIRE_LOCK_TIMEOUT, transaction: true)
      @customer = customer
      @scope = scope
      @timeout_seconds = timeout_seconds
      @transaction = transaction

      validate_scope!

      super
    end

    def call
      Customer.with_advisory_lock!(lock_key, timeout_seconds:, transaction:) do
        yield
      end
    rescue WithAdvisoryLock::FailedToAcquireLock
      raise FailedToAcquireLock, "Failed to acquire lock #{lock_key}"
    end

    def locked?
      ActiveRecord::Base.advisory_lock_exists?(lock_key)
    end

    private

    attr_reader :customer, :scope, :timeout_seconds, :transaction

    def validate_scope!
      return if VALID_SCOPES.include?(scope)

      raise ArgumentError, "Invalid scope: #{scope}. Valid scopes are: #{VALID_SCOPES.join(", ")}"
    end

    def lock_key
      "customer-#{customer.id}-#{scope}"
    end
  end
end
