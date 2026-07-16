# frozen_string_literal: true

module Mutations
  module Customers
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "customers:delete"

      graphql_name "DestroyCustomer"
      description "Delete a Customer"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        customer = current_organization.customers.find_by(id:)
        result = ::Customers::DestroyService.call(customer:)

        result.success? ? result.customer : result_error(result)
      end
    end
  end
end
