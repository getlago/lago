# frozen_string_literal: true

module Types
  module WalletTransactions
    class MetadataObject < Types::BaseObject
      graphql_name "WalletTransactionMetadataObject"

      field :key, String, null: false
      field :value, String, null: false
    end
  end
end
