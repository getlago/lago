# frozen_string_literal: true

module Mutations
  module Wallets
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:update"

      graphql_name "UpdateCustomerWallet"
      description "Updates a new Customer Wallet"

      input_object_class Types::Wallets::UpdateInput

      type Types::Wallets::Object

      def resolve(**args)
        wallet = current_organization.wallets.find_by(id: args[:id])
        result = ::Wallets::UpdateService.call(wallet:, params: args)

        result.success? ? result.wallet : result_error(result)
      end
    end
  end
end
