# frozen_string_literal: true

module Mutations
  module Integrations
    module Okta
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateOktaIntegration"
        description "Update Okta integration"

        input_object_class Types::Integrations::Okta::UpdateInput

        type Types::Integrations::Okta

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Okta::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
