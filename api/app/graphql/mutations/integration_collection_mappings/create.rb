# frozen_string_literal: true

module Mutations
  module IntegrationCollectionMappings
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "CreateIntegrationCollectionMapping"
      description "Create integration collection mapping"

      input_object_class Types::IntegrationCollectionMappings::CreateInput

      type Types::IntegrationCollectionMappings::Object

      def resolve(**args)
        result = ::IntegrationCollectionMappings::CreateService
          .call(params: args.merge(organization_id: current_organization.id))

        result.success? ? result.integration_collection_mapping : result_error(result)
      end
    end
  end
end
