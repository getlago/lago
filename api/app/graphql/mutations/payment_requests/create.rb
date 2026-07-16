# frozen_string_literal: true

module Mutations
  module PaymentRequests
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payments:create"

      graphql_name "CreatePaymentRequest"
      description "Creates a payment request"

      input_object_class Types::PaymentRequests::CreateInput
      type Types::PaymentRequests::Object

      def resolve(**args)
        result = ::PaymentRequests::CreateService.call(organization: current_organization, params: args)
        result.success? ? result.payment_request : result_error(result)
      end
    end
  end
end
