# frozen_string_literal: true

module Clock
  class RetryGeneratingSubscriptionInvoicesJob < ClockJob
    unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

    THRESHOLD = -> { 1.day.ago }

    def perform
      ids = ErrorDetail.invoice_generation_error.where(owner_type: "Invoice").pluck(:owner_id)
      Invoice.subscription.generating.where.not(id: ids).where("created_at < ?", THRESHOLD.call).find_each do |invoice|
        next unless invoice.invoice_subscriptions.any?
        invoicing_reasons = invoice.invoice_subscriptions.pluck(:invoicing_reason).uniq.compact
        invoicing_reason = (invoicing_reasons.size == 1) ? invoicing_reasons.first : :upgrading

        next if invoicing_reason.to_s == "in_advance_charge"

        BillSubscriptionJob.perform_later(
          invoice.subscriptions.to_a,
          invoice.invoice_subscriptions.first.timestamp.to_i,
          invoicing_reason:,
          invoice:,
          skip_charges: invoice.skip_charges
        )
      end
    end
  end
end
