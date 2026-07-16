# frozen_string_literal: true

module Mutations
  module Integrations
    module Salesforce
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateSalesforceIntegration"
        description "Create Salesforce integration"

        input_object_class Types::Integrations::Salesforce::CreateInput

        type Types::Integrations::Salesforce

        def resolve(**args)
          result = ::Integrations::Salesforce::CreateService
            .call(params: args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
