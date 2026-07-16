# frozen_string_literal: true

module Mutations
  module Integrations
    module Netsuite
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateNetsuiteIntegration"
        description "Create Netsuite integration"

        input_object_class Types::Integrations::Netsuite::CreateInput

        type Types::Integrations::Netsuite

        def resolve(**args)
          result = ::Integrations::Netsuite::CreateService
            .call(params: args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
