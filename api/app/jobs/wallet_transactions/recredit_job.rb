# frozen_string_literal: true

module WalletTransactions
  class RecreditJob < ApplicationJob
    queue_as "default"

    def perform(wallet_transaction)
      return unless wallet_transaction.wallet.active?

      WalletTransactions::RecreditService.call!(wallet_transaction:)
    end
  end
end
