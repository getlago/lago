# frozen_string_literal: true

module Mutations
  module Organizations
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      graphql_name "UpdateOrganization"
      description "Updates an Organization"

      input_object_class Types::Organizations::UpdateOrganizationInput

      type Types::Organizations::CurrentOrganizationType

      def resolve(**args)
        result = ::Organizations::UpdateService.call(
          organization: current_organization,
          params: args,
          user: context[:current_user]
        )
        result.success? ? result.organization : result_error(result)
      end
    end
  end
end
