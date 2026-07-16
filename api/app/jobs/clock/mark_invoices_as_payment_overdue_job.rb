# frozen_string_literal: true

module Clock
  class MarkInvoicesAsPaymentOverdueJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      Invoice
        .finalized
        .not_payment_succeeded
        .where(payment_overdue: false)
        .where(payment_dispute_lost_at: nil)
        .where(payment_due_date: ...Time.current)
        .in_batches(of: 1000, cursor: [:payment_due_date, :id]) do |batch|
          batch.each do |invoice|
            Invoices::Payments::MarkOverdueJob.perform_later(invoice:)
          end
        end
    end
  end
end
