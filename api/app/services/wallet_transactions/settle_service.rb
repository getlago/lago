# frozen_string_literal: true

module WalletTransactions
  class SettleService < BaseService
    Result = BaseResult[:wallet_transaction]

    def initialize(wallet_transaction:)
      super(nil)

      @wallet_transaction = wallet_transaction
    end

    activity_loggable(
      action: "wallet_transaction.updated",
      record: -> { wallet_transaction }
    )

    def call
      updates = {status: :settled, settled_at: Time.current}

      if wallet_transaction.inbound? && wallet_transaction.wallet.traceable?
        updates[:remaining_amount_cents] = wallet_transaction.amount_cents
      end

      wallet_transaction.update!(updates)
      after_commit { SendWebhookJob.perform_later("wallet_transaction.updated", wallet_transaction) }

      result.wallet_transaction = wallet_transaction
      result
    end

    private

    attr_reader :wallet_transaction
  end
end
