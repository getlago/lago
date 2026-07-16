# frozen_string_literal: true

module V1
  module PaymentProviders
    class InvoicePaymentErrorSerializer < ModelSerializer
      alias_method :invoice, :model

      def serialize
        {
          lago_invoice_id: invoice.id,
          lago_customer_id: invoice.customer.id,
          external_customer_id: invoice.customer.external_id,
          provider_customer_id: options[:provider_customer_id],
          payment_provider: invoice.customer.payment_provider,
          payment_provider_code: invoice.customer.payment_provider_code,
          provider_error: options[:provider_error],
          error_details: options[:error_details]
        }
      end
    end
  end
end
