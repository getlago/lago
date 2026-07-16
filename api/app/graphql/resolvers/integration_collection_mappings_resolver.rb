# frozen_string_literal: true

module Resolvers
  class IntegrationCollectionMappingsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "organization:integrations:view"

    description "Query integration collection mappings"

    argument :integration_id, ID, required: true

    type Types::IntegrationCollectionMappings::Object.collection_type, null: true

    def resolve(integration_id:)
      result = ::IntegrationCollectionMappingsQuery.call(
        organization: current_organization,
        filters: {integration_id:}
      )

      result.integration_collection_mappings
    end
  end
end
