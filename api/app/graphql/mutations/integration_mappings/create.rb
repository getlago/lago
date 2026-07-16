# frozen_string_literal: true

module Mutations
  module IntegrationMappings
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "CreateIntegrationMapping"
      description "Create integration mapping"

      input_object_class Types::IntegrationMappings::CreateInput

      type Types::IntegrationMappings::Object

      def resolve(**args)
        result = ::IntegrationMappings::CreateService
          .new(context[:current_user])
          .call(**args.merge(organization_id: current_organization.id))

        result.success? ? result.integration_mapping : result_error(result)
      end
    end
  end
end
