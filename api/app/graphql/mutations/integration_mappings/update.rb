# frozen_string_literal: true

module Mutations
  module IntegrationMappings
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:update"

      graphql_name "UpdateIntegrationMapping"
      description "Update integration mapping"

      input_object_class Types::IntegrationMappings::UpdateInput

      type Types::IntegrationMappings::Object

      def resolve(**args)
        integration_mapping = ::IntegrationMappings::BaseMapping
          .joins(:integration)
          .where(id: args[:id], integration: {organization: current_organization}).first

        result = ::IntegrationMappings::UpdateService.call(integration_mapping:, params: args)

        result.success? ? result.integration_mapping : result_error(result)
      end
    end
  end
end
