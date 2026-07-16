# frozen_string_literal: true

module V1
  module PaymentProviders
    class PaymentRequestPaymentErrorSerializer < ModelSerializer
      alias_method :payment_request, :model

      def serialize
        {
          lago_payment_request_id: payment_request.id,
          lago_invoice_ids: payment_request.invoice_ids,
          lago_customer_id: payment_request.customer.id,
          external_customer_id: payment_request.customer.external_id,
          provider_customer_id: options[:provider_customer_id],
          payment_provider: payment_request.customer.payment_provider,
          payment_provider_code: payment_request.customer.payment_provider_code,
          provider_error: options[:provider_error]
        }
      end
    end
  end
end
