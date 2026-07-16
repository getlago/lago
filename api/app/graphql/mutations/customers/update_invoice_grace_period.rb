# frozen_string_literal: true

# TODO: Remove this mutation
# The Mutations::Customers::Update allows you to modify the customer grace period
module Mutations
  module Customers
    class UpdateInvoiceGracePeriod < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = %w[customers:update]

      graphql_name "UpdateCustomerInvoiceGracePeriod"
      description "Assign the invoice grace period to Customers"

      argument :id, ID, required: true
      argument :invoice_grace_period, Integer, required: false

      type Types::Customers::Object

      def resolve(id:, invoice_grace_period:)
        customer = current_organization.customers.find_by(id:)
        result = ::Customers::UpdateService.call(customer:, args: {invoice_grace_period:})

        result.success? ? result.customer : result_error(result)
      end
    end
  end
end
