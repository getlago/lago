# frozen_string_literal: true

module Resolvers
  class WalletTransactionResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query a single wallet transaction"

    argument :id, ID, required: true, description: "Unique ID of the wallet transaction"

    type Types::WalletTransactions::Object, null: true

    def resolve(id:)
      current_organization.wallet_transactions.includes(:invoice).find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "wallet_transaction")
    end
  end
end
