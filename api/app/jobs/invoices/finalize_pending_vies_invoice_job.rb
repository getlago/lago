# frozen_string_literal: true

module Invoices
  class FinalizePendingViesInvoiceJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :invoices
      end
    end

    unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

    retry_on Customers::FailedToAcquireLock, ActiveRecord::StaleObjectError, attempts: MAX_LOCK_RETRY_ATTEMPTS, wait: random_lock_retry_delay

    def perform(invoice)
      Invoices::FinalizePendingViesInvoiceService.call!(invoice:)
    end
  end
end
