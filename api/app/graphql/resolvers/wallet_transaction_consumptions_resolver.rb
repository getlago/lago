# frozen_string_literal: true

module Resolvers
  class WalletTransactionConsumptionsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query wallet transaction consumptions for an inbound transaction"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :wallet_transaction_id, ID, required: true, description: "Uniq ID of the inbound wallet transaction"

    type Types::WalletTransactionConsumptions::Object.collection_type, null: false

    def resolve(wallet_transaction_id:, page: nil, limit: nil)
      result = WalletTransactionConsumptionsQuery.call(
        organization: current_organization,
        filters: {
          wallet_transaction_id:,
          direction: :consumptions
        },
        pagination: {page:, limit:}
      )

      return result_error(result) unless result.success?

      result.wallet_transaction_consumptions
    end
  end
end
