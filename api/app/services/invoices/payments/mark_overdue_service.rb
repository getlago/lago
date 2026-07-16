# frozen_string_literal: true

module Invoices
  module Payments
    class MarkOverdueService < BaseService
      Result = BaseResult[:invoice]

      def initialize(invoice:)
        @invoice = invoice

        super
      end

      activity_loggable(
        action: "invoice.payment_overdue",
        record: -> { invoice }
      )

      def call
        return result.not_found_failure!(resource: "invoice") unless invoice
        return result.not_allowed_failure!(code: "invoice_not_finalized") unless invoice.finalized?
        return result.not_allowed_failure!(code: "invoice_payment_already_succeeded") if invoice.payment_succeeded?
        return result.not_allowed_failure!(code: "invoice_due_date_in_future") if invoice.payment_due_date > Time.current
        return result.not_allowed_failure!(code: "invoice_dispute_lost") if invoice.payment_dispute_lost_at

        invoice.update!(payment_overdue: true)

        result.invoice = invoice

        SendWebhookJob.perform_later("invoice.payment_overdue", invoice)
        result
      end

      private

      attr_reader :invoice
    end
  end
end
