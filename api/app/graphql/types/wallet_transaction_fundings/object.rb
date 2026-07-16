# frozen_string_literal: true

module Types
  module WalletTransactionFundings
    class Object < Types::BaseObject
      graphql_name "WalletTransactionFunding"

      field :amount_cents, GraphQL::Types::BigInt, null: false, method: :consumed_amount_cents
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :credit_amount, String, null: false
      field :id, ID, null: false
      field :wallet_transaction, Types::WalletTransactions::Object, null: false, method: :inbound_wallet_transaction
    end
  end
end
