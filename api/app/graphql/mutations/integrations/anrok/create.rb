# frozen_string_literal: true

module Mutations
  module Integrations
    module Anrok
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateAnrokIntegration"
        description "Create Anrok integration"

        input_object_class Types::Integrations::Anrok::CreateInput

        type Types::Integrations::Anrok

        def resolve(**args)
          result = ::Integrations::Anrok::CreateService
            .new(context[:current_user])
            .call(**args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
