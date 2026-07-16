# frozen_string_literal: true

module Mutations
  module IntegrationCollectionMappings
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "DestroyIntegrationCollectionMapping"
      description "Destroy an integration collection mapping"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        integration_collection_mapping = ::IntegrationCollectionMappings::BaseCollectionMapping
          .joins(:integration)
          .where(id:)
          .where(integration: {organization: current_organization}).first

        result = ::IntegrationCollectionMappings::DestroyService.call(integration_collection_mapping:)

        result.success? ? result.integration_collection_mapping : result_error(result)
      end
    end
  end
end
