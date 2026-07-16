# frozen_string_literal: true

module Invoices
  class RefreshDraftJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :invoices
      end
    end

    unique :until_executed, on_conflict: :log, lock_ttl: 12.hours

    def perform(invoice:)
      # if this has already been set to false, we can skip the job
      return unless invoice.ready_to_be_refreshed?

      ::Invoices::RefreshDraftService.call(invoice:)
    end
  end
end
