# frozen_string_literal: true

module Clock
  class RefreshDraftInvoicesJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      Invoice.ready_to_be_refreshed.with_active_subscriptions.find_each do |invoice|
        Invoices::RefreshDraftJob.perform_later(invoice:)
      end
    end
  end
end
