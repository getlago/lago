# frozen_string_literal: true

module Mutations
  module PaymentMethods
    class SetAsDefault < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payment_methods:update"

      description "Set payment method as default"

      argument :id, ID, required: true

      type Types::PaymentMethods::Object

      def resolve(**args)
        payment_method = current_organization.payment_methods.find_by(id: args[:id])
        result = ::PaymentMethods::SetAsDefaultService.call(payment_method:)

        result.success? ? result.payment_method : result_error(result)
      end
    end
  end
end
