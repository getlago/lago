# frozen_string_literal: true

module Mutations
  module Roles
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "roles:delete"

      graphql_name "DestroyRole"
      description "Deletes a custom role"

      argument :id, ID, required: true

      type Types::RoleType

      def resolve(id:)
        role = Role.with_organization(current_organization.id).find_by(id:)
        result = ::Roles::DestroyService.call(role:)

        result.success? ? result.role : result_error(result)
      end
    end
  end
end
