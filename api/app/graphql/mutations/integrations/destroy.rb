# frozen_string_literal: true

module Mutations
  module Integrations
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:delete"

      graphql_name "DestroyIntegration"
      description "Destroy an integration"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        integration = current_organization.integrations.find_by(id:)
        result = destroy_service(integration:).call(integration:)

        result.success? ? result.integration : result_error(result)
      end

      private

      def destroy_service(integration:)
        case integration
        when ::Integrations::OktaIntegration
          ::Integrations::Okta::DestroyService
        else
          ::Integrations::DestroyService
        end
      end
    end
  end
end
