# frozen_string_literal: true

module Mutations
  module Integrations
    module Xero
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateXeroIntegration"
        description "Update Xero integration"

        input_object_class Types::Integrations::Xero::UpdateInput

        type Types::Integrations::Xero

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Xero::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
