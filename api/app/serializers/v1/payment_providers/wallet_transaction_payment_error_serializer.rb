# frozen_string_literal: true

module V1
  module PaymentProviders
    class WalletTransactionPaymentErrorSerializer < ModelSerializer
      alias_method :wallet_transaction, :model

      def serialize
        {
          lago_wallet_transaction_id: wallet_transaction.id,
          lago_customer_id: customer.id,
          external_customer_id: customer.external_id,
          provider_customer_id: options[:provider_customer_id],
          payment_provider: customer.payment_provider,
          payment_provider_code: customer.payment_provider_code,
          provider_error: options[:provider_error]
        }
      end

      private

      def customer
        wallet_transaction.wallet.customer
      end
    end
  end
end
