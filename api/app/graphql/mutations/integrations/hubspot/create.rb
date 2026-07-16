# frozen_string_literal: true

module Mutations
  module Integrations
    module Hubspot
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateHubspotIntegration"
        description "Create Hubspot integration"

        input_object_class Types::Integrations::Hubspot::CreateInput

        type Types::Integrations::Hubspot

        def resolve(**args)
          result = ::Integrations::Hubspot::CreateService
            .call(params: args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
