# frozen_string_literal: true

module Resolvers
  class WalletTransactionFundingsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query wallet transaction fundings for an outbound transaction"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :wallet_transaction_id, ID, required: true, description: "Uniq ID of the outbound wallet transaction"

    type Types::WalletTransactionFundings::Object.collection_type, null: false

    def resolve(wallet_transaction_id:, page: nil, limit: nil)
      result = WalletTransactionConsumptionsQuery.call(
        organization: current_organization,
        filters: {
          wallet_transaction_id:,
          direction: :fundings
        },
        pagination: {page:, limit:}
      )

      return result_error(result) unless result.success?

      result.wallet_transaction_consumptions
    end
  end
end
