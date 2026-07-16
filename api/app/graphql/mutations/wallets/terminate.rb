# frozen_string_literal: true

module Mutations
  module Wallets
    class Terminate < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:terminate"

      graphql_name "TerminateCustomerWallet"
      description "Terminates a new Customer Wallet"

      argument :id, ID, required: true

      type Types::Wallets::Object

      def resolve(id:)
        wallet = current_organization.wallets.find_by(id:)
        result = ::Wallets::TerminateService.call(wallet:)

        result.success? ? result.wallet : result_error(result)
      end
    end
  end
end
