# frozen_string_literal: true

module Mutations
  module Payments
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "payments:create"

      graphql_name "CreatePayment"
      description "Creates a manual payment"

      input_object_class Types::Payments::CreateInput
      type Types::Payments::Object

      def resolve(**args)
        result = ::Payments::ManualCreateService.call(organization: current_organization, params: args)
        result.success? ? result.payment : result_error(result)
      end
    end
  end
end
