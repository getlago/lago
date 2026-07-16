# frozen_string_literal: true

module Types
  module WalletTransactions
    class SourceEnum < Types::BaseEnum
      graphql_name "WalletTransactionSourceEnum"

      WalletTransaction::SOURCES.each do |type|
        value type
      end
    end
  end
end
