# frozen_string_literal: true

module Mutations
  module BillingEntities
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "billing_entities:create"

      graphql_name "CreateBillingEntity"
      description "Creates a new Billing Entity"

      input_object_class Types::BillingEntities::CreateInput

      type Types::BillingEntities::Object

      def resolve(**args)
        result = ::BillingEntities::CreateService.call(
          organization: current_organization,
          params: args
        )

        result.success? ? result.billing_entity : result_error(result)
      end
    end
  end
end
