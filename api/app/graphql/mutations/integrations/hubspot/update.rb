# frozen_string_literal: true

module Mutations
  module Integrations
    module Hubspot
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateHubspotIntegration"
        description "Update Hubspot integration"

        input_object_class Types::Integrations::Hubspot::UpdateInput

        type Types::Integrations::Hubspot

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Hubspot::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
