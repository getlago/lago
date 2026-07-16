# frozen_string_literal: true

module Webhooks
  module CreditNotes
    class PaymentProviderRefundFailureService < Webhooks::BaseService
      private

      alias_method :credit_note, :object

      def object_serializer
        ::V1::CreditNotes::PaymentProviderRefundErrorSerializer.new(
          credit_note,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider_customer_id: options[:provider_customer_id]
        )
      end

      def webhook_type
        "credit_note.refund_failure"
      end

      def object_type
        "credit_note_payment_provider_refund_error"
      end
    end
  end
end
