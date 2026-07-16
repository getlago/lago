# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class WalletTransactionPaymentFailureService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::WalletTransactionPaymentErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider_customer_id: options[:provider_customer_id]
        )
      end

      def webhook_type
        "wallet_transaction.payment_failure"
      end

      def object_type
        "payment_provider_wallet_transaction_payment_error"
      end
    end
  end
end
