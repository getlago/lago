# frozen_string_literal: true

class BillNonInvoiceableFeesJob < ApplicationJob
  queue_as do
    if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
      :billing
    else
      :default
    end
  end

  retry_on Sequenced::SequenceError, ActiveJob::DeserializationError, wait: :polynomially_longer, attempts: 15, jitter: 0.75

  unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

  def perform(subscriptions, billing_at)
    result = Invoices::AdvanceChargesService.call(initial_subscriptions: subscriptions, billing_at:)
    result.raise_if_error!
  end
end
