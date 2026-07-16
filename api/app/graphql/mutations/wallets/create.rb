# frozen_string_literal: true

module Mutations
  module Wallets
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:create"

      graphql_name "CreateCustomerWallet"
      description "Creates a new Customer Wallet"

      input_object_class Types::Wallets::CreateInput

      type Types::Wallets::Object

      def resolve(**args)
        result = ::Wallets::CreateService.call(
          params: args.merge(organization_id: current_organization.id)
            .merge(customer: current_customer(args[:customer_id]))
            .except(:customer_id)
        )

        result.success? ? result.wallet : result_error(result)
      end

      def current_customer(id)
        current_organization.customers.find_by(id:)
      end
    end
  end
end
