# frozen_string_literal: true

module Mutations
  module Roles
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "roles:update"

      graphql_name "UpdateRole"
      description "Updates an existing custom role"

      input_object_class Types::Roles::UpdateInput

      type Types::RoleType

      def resolve(id:, **args)
        role = Role.with_organization(current_organization.id).find_by(id:)
        result = ::Roles::UpdateService.call(role:, params: args)

        result.success? ? result.role : result_error(result)
      end
    end
  end
end
