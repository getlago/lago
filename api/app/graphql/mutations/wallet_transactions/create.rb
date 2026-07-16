# frozen_string_literal: true

module Mutations
  module WalletTransactions
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:top_up"

      graphql_name "CreateCustomerWalletTransaction"
      description "Creates a new Customer Wallet Transaction"

      input_object_class Types::WalletTransactions::CreateInput

      type Types::WalletTransactions::Object.collection_type

      def resolve(**args)
        result = ::WalletTransactions::CreateFromParamsService.call(organization: current_organization, params: args)

        result.success? ? result.wallet_transactions : result_error(result)
      end
    end
  end
end
