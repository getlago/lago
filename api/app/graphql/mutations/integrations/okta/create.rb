# frozen_string_literal: true

module Mutations
  module Integrations
    module Okta
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateOktaIntegration"
        description "Create Okta integration"

        input_object_class Types::Integrations::Okta::CreateInput

        type Types::Integrations::Okta

        def resolve(**args)
          result = ::Integrations::Okta::CreateService
            .new(context[:current_user])
            .call(**args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
