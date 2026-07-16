# frozen_string_literal: true

module Mutations
  module Integrations
    module Xero
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "CreateXeroIntegration"
        description "Create Xero integration"

        input_object_class Types::Integrations::Xero::CreateInput

        type Types::Integrations::Xero

        def resolve(**args)
          result = ::Integrations::Xero::CreateService
            .new(context[:current_user])
            .call(**args.merge(organization_id: current_organization.id))

          result.success? ? result.integration : result_error(result)
        end
      end
    end
  end
end
