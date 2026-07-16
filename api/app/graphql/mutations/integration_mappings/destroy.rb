# frozen_string_literal: true

module Mutations
  module IntegrationMappings
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "DestroyIntegrationMapping"
      description "Destroy an integration mapping"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        integration_mapping = ::IntegrationMappings::BaseMapping
          .joins(:integration)
          .where(id:)
          .where(integration: {organization: current_organization}).first

        result = ::IntegrationMappings::DestroyService.call(integration_mapping:)

        result.success? ? result.integration_mapping : result_error(result)
      end
    end
  end
end
