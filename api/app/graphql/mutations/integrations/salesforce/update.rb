# frozen_string_literal: true

module Mutations
  module Integrations
    module Salesforce
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateSalesforceIntegration"
        description "Update Salesforce integration"

        input_object_class Types::Integrations::Salesforce::UpdateInput

        type Types::Integrations::Salesforce

        def resolve(**args)
          integration = current_organization.integrations.find_by(id: args[:id])
          result = ::Integrations::Salesforce::UpdateService.call(integration:, params: args)

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
