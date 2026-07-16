# frozen_string_literal: true

module Mutations
  module Integrations
    module Anrok
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateAnrokIntegration"
        description "Update Anrok integration"

        input_object_class Types::Integrations::Anrok::UpdateInput

        type Types::Integrations::Anrok

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Anrok::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
