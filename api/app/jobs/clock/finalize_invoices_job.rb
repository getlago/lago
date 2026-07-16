# frozen_string_literal: true

module Clock
  class FinalizeInvoicesJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      Invoice.ready_to_be_finalized.find_each do |invoice|
        Invoices::FinalizeJob.perform_later(invoice)
      end
    end
  end
end
