# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class TransactionMetadataInput < Types::BaseInputObject
        graphql_name "CreateTransactionMetadataInput"

        argument :key, String, required: true
        argument :value, String, required: true
      end
    end
  end
end
