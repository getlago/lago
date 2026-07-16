# frozen_string_literal: true

module Mutations
  module Integrations
    module Avalara
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateAvalaraIntegration"
        description "Create Avalara integration"

        input_object_class Types::Integrations::Avalara::CreateInput

        type Types::Integrations::Avalara

        def resolve(**args)
          result = ::Integrations::Avalara::CreateService
            .call(params: args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
