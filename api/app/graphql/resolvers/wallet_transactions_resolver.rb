# frozen_string_literal: true

module Resolvers
  class WalletTransactionsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query wallet transactions"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :status, Types::WalletTransactions::StatusEnum, required: false
    argument :transaction_type, Types::WalletTransactions::TransactionTypeEnum, required: false
    argument :wallet_id, ID, required: true, description: "Uniq ID of the wallet"

    type Types::WalletTransactions::Object.collection_type, null: false

    def resolve(
      wallet_id: nil,
      page: nil,
      limit: nil,
      status: nil,
      transaction_type: nil
    )
      result = WalletTransactionsQuery.call(
        organization: current_organization,
        wallet_id:,
        pagination: {
          page:,
          limit:
        },
        filters: {
          status:,
          transaction_type:
        }
      )

      return result_error(result) unless result.success?

      result.wallet_transactions
    end
  end
end
