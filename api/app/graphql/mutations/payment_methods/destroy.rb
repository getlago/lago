# frozen_string_literal: true

module Mutations
  module PaymentMethods
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payment_methods:delete"

      graphql_name "DestroyPaymentMethod"
      description "Deletes a payment method"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        payment_method = current_organization.payment_methods.find_by(id:)
        result = ::PaymentMethods::DestroyService.call(payment_method:)

        result.success? ? result.payment_method : result_error(result)
      end
    end
  end
end
