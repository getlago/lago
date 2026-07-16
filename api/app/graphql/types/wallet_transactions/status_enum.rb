# frozen_string_literal: true

module Types
  module WalletTransactions
    class StatusEnum < Types::BaseEnum
      graphql_name "WalletTransactionStatusEnum"

      WalletTransaction::STATUSES.each do |type|
        value type
      end
    end
  end
end
