# frozen_string_literal: true

module Mutations
  module PaymentMethods
    class GenerateCheckoutUrl < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payment_methods:create"

      description "Generates checkout url for payment method"

      argument :customer_id, ID, required: true

      field :checkout_url, String, null: false

      def resolve(**args)
        customer = current_organization.customers.find_by(id: args[:customer_id])

        result = ::Customers::GenerateCheckoutUrlService.call(customer:)

        result.success? ? result : result_error(result)
      end
    end
  end
end
