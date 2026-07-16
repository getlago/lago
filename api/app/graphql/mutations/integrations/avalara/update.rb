# frozen_string_literal: true

module Mutations
  module Integrations
    module Avalara
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateAvalaraIntegration"
        description "Update Avalara integration"

        input_object_class Types::Integrations::Avalara::UpdateInput

        type Types::Integrations::Avalara

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Avalara::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
