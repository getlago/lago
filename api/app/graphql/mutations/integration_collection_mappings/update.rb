# frozen_string_literal: true

module Mutations
  module IntegrationCollectionMappings
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "UpdateIntegrationCollectionMapping"
      description "Update integration mapping"

      input_object_class Types::IntegrationCollectionMappings::UpdateInput

      type Types::IntegrationCollectionMappings::Object

      def resolve(id:, **args)
        integration_collection_mapping = ::IntegrationCollectionMappings::BaseCollectionMapping
          .joins(:integration)
          .find_by(id:, integration: {organization: current_organization})

        result = ::IntegrationCollectionMappings::UpdateService.call(
          integration_collection_mapping:,
          params: args
        )

        result.success? ? result.integration_collection_mapping : result_error(result)
      end
    end
  end
end
