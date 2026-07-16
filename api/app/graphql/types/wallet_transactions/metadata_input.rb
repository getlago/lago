# frozen_string_literal: true

module Types
  module WalletTransactions
    class MetadataInput < Types::BaseInputObject
      graphql_name "WalletTransactionMetadataInput"

      argument :key, String, required: true
      argument :value, String, required: true
    end
  end
end
