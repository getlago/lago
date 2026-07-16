# frozen_string_literal: true

module V1
  module PaymentProviders
    class WalletTransactionPaymentSerializer < ModelSerializer
      def serialize
        {
          lago_customer_id: customer.id,
          external_customer_id: customer.external_id,
          payment_provider: customer.payment_provider,
          lago_wallet_transaction_id: model.id,
          payment_url: options[:payment_url]
        }
      end

      private

      def customer
        @customer ||= model.invoice.customer
      end
    end
  end
end
