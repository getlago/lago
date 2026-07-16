# frozen_string_literal: true

module Invoices
  class CreatePayInAdvanceFixedChargesJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :default
      end
    end

    retry_on Sequenced::SequenceError, wait: :polynomially_longer, attempts: 15, jitter: 0.75
    retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

    retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError, attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay

    unique :until_executed, on_conflict: :log

    def perform(subscription, timestamp)
      result = Invoices::CreatePayInAdvanceFixedChargesService.call(
        subscription:,
        timestamp:
      )

      return if result.success?

      # NOTE: We don't want a dead job for failed invoice due to the tax reason.
      #       This invoice should be in failed status and can be retried.
      return if tax_error?(result)

      result.raise_if_error!
    end

    private

    def tax_error?(result)
      return false unless result.error.is_a?(BaseService::ValidationFailure)

      result.error.messages&.dig(:tax_error).present?
    end
  end
end
