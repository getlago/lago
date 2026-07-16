# frozen_string_literal: true

module Wallets
  class ApplyPaidCreditsService < BaseService
    Result = BaseResult[:wallet_transaction]

    def initialize(wallet_transaction:)
      @wallet_transaction = wallet_transaction
      super
    end

    def call
      return result unless wallet_transaction
      return result if wallet_transaction.status == "settled"

      ActiveRecord::Base.transaction do
        WalletTransactions::SettleService.new(wallet_transaction:).call
        Wallets::Balance::IncreaseService
          .new(wallet: wallet_transaction.wallet, wallet_transaction: wallet_transaction).call
      end

      result.wallet_transaction = wallet_transaction
      result
    end

    private

    attr_reader :wallet_transaction
  end
end
