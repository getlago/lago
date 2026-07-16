# frozen_string_literal: true

module PaymentRequests
  module Payments
    module Updatable
      extend ActiveSupport::Concern

      private

      def update_invoices_paid_amount_cents(payment_status:)
        return if !payable || payment_status.to_sym != :succeeded

        payable.invoices.each do |invoice|
          Invoices::UpdateService.call!(invoice:, params: {
            total_paid_amount_cents: total_paid_amount_cents(invoice)
          })
        end
      end

      def total_paid_amount_cents(invoice)
        invoice.total_paid_amount_cents + invoice.total_due_amount_cents
      end
    end
  end
end
