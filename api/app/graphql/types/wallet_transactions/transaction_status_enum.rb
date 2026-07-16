# frozen_string_literal: true

module Types
  module WalletTransactions
    class TransactionStatusEnum < Types::BaseEnum
      graphql_name "WalletTransactionTransactionStatusEnum"

      WalletTransaction::TRANSACTION_STATUSES.each do |type|
        value type
      end
    end
  end
end
