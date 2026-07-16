# frozen_string_literal: true

module Webhooks
  module Wallets
    class UpdatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::WalletSerializer.new(object, root_name: "wallet", includes: %i[recurring_transaction_rules])
      end

      def webhook_type
        "wallet.updated"
      end

      def object_type
        "wallet"
      end
    end
  end
end
