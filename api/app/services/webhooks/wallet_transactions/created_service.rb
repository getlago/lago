# frozen_string_literal: true

module Webhooks
  module WalletTransactions
    class CreatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::WalletTransactionSerializer.new(object, root_name: "wallet_transaction", includes: %i[wallet])
      end

      def webhook_type
        "wallet_transaction.created"
      end

      def object_type
        "wallet_transaction"
      end
    end
  end
end
