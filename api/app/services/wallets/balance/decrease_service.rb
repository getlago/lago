# frozen_string_literal: true

module Wallets
  module Balance
    class DecreaseService < BaseService
      Result = BaseResult[:wallet]

      def initialize(wallet:, wallet_transaction:, skip_refresh: false)
        @wallet = wallet.reload
        @wallet_transaction = wallet_transaction
        @skip_refresh = skip_refresh

        super
      end

      def call
        transaction_credits_amount = wallet_transaction.credit_amount

        wallet.update!(
          balance_cents: wallet.balance_cents - wallet_transaction.amount_cents,
          credits_balance: wallet.credits_balance - transaction_credits_amount,
          last_balance_sync_at: Time.zone.now,
          consumed_credits: wallet.consumed_credits + transaction_credits_amount,
          consumed_amount_cents: wallet.consumed_amount_cents + wallet_transaction.amount_cents,
          last_consumed_credit_at: Time.current
        )

        unless skip_refresh
          wallet.customer.flag_wallets_for_refresh
          Customers::RefreshWalletJob.perform_after_commit(wallet.customer)
        end

        SendWebhookJob.perform_after_commit("wallet.updated", wallet)
        UsageMonitoring::ProcessWalletAlertsJob.perform_after_commit(wallet)

        result.wallet = wallet
        result
      end

      private

      attr_reader :wallet, :wallet_transaction, :skip_refresh
    end
  end
end
