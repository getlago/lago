# frozen_string_literal: true

module Fees
  class CreatePayInAdvanceJob < ApplicationJob
    queue_as :default

    # Random jitter (in seconds) added to every retry so parallel failed jobs
    # don't retry in lockstep and overload Clickhouse again at the same instant.
    RETRY_JITTER = 1..15

    retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25

    # Increasing backoff (a few seconds, then longer and longer) plus jitter, to give
    # Clickhouse time to recover from too many high-usage parallel calls.
    retry_on Events::Stores::Clickhouse::MemoryLimitError,
      wait: ->(executions) { Fees::CreatePayInAdvanceJob.retry_wait(executions) },
      attempts: 25

    def self.retry_wait(executions)
      (executions**4) + rand(RETRY_JITTER)
    end

    unique :until_executed, on_conflict: :log

    def perform(charge:, event:, billing_at: nil)
      result = Fees::CreatePayInAdvanceService.call(charge:, event:, billing_at:)

      return if !result.success? && tax_error?(result)

      result.raise_if_error!
    end

    def lock_key_arguments
      args = arguments.first
      event = Events::CommonFactory.new_instance(source: args[:event])
      [args[:charge], event.organization_id, event.external_subscription_id, event.transaction_id]
    end

    private

    def tax_error?(result)
      return false unless result.error.is_a?(BaseService::ValidationFailure)

      result.error&.messages&.dig(:tax_error).present?
    end
  end
end
