# frozen_string_literal: true

module Wallets
  module Balance
    class IncreaseService < BaseService
      Result = BaseResult[:wallet]

      def initialize(wallet:, wallet_transaction:, reset_consumed_credits: false)
        super

        @wallet = wallet
        @wallet_transaction = wallet_transaction
        @reset_consumed_credits = reset_consumed_credits
      end

      def call
        transaction_credits_amount = wallet_transaction.credit_amount
        transaction_amount_cents = wallet_transaction.amount_cents

        currency = wallet.currency_for_balance
        update_params = {
          balance_cents: wallet.balance_cents + transaction_amount_cents,
          credits_balance: wallet.credits_balance + transaction_credits_amount,
          last_balance_sync_at: Time.current
        }

        if reset_consumed_credits
          update_params[:consumed_credits] = [0.0, wallet.consumed_credits - transaction_credits_amount].max
          update_params[:consumed_amount_cents] = [0, ((wallet.consumed_credits - transaction_credits_amount) * wallet.rate_amount * currency.subunit_to_unit).floor].max
        end

        wallet.update!(update_params)

        # we only need to update all wallets when there is usage applied. In case we're increasing balance of only one wallet,
        # only this wallet will be affected and needs recalculation
        Customers::RefreshWalletJob.perform_after_commit(wallet.customer, wallet_ids: [wallet.id])
        SendWebhookJob.perform_after_commit("wallet.updated", wallet)
        UsageMonitoring::ProcessWalletAlertsJob.perform_after_commit(wallet)

        result.wallet = wallet
        result
      end

      private

      attr_reader :wallet, :wallet_transaction, :reset_consumed_credits
    end
  end
end
