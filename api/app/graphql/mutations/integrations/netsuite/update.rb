# frozen_string_literal: true

module Mutations
  module Integrations
    module Netsuite
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateNetsuiteIntegration"
        description "Update Netsuite integration"

        input_object_class Types::Integrations::Netsuite::UpdateInput

        type Types::Integrations::Netsuite

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Netsuite::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
