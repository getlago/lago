# frozen_string_literal: true

module Wallets
  module Balance
    class UpdateOngoingService < BaseService
      Result = BaseResult[:wallet]

      def initialize(wallet:, update_params:, skip_single_wallet_update: false)
        super

        @wallet = wallet
        update_params[:last_ongoing_balance_sync_at] = Time.current unless skip_single_wallet_update
        @update_params = update_params
      end

      def call
        wallet.update!(update_params)

        after_commit do
          if update_params[:depleted_ongoing_balance] == true
            SendWebhookJob.perform_later("wallet.depleted_ongoing_balance", wallet)
          end

          ::Wallets::ThresholdTopUpService.call(wallet:)
          UsageMonitoring::ProcessWalletAlertsJob.perform_later(wallet)
        end

        result.wallet = wallet
        result
      end

      private

      attr_reader :wallet, :update_params
    end
  end
end
