# frozen_string_literal: true

module Webhooks
  module Wallets
    class DepletedOngoingBalanceService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::WalletSerializer.new(object, root_name: "wallet")
      end

      def webhook_type
        "wallet.depleted_ongoing_balance"
      end

      def object_type
        "wallet"
      end
    end
  end
end
