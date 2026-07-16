# frozen_string_literal: true

module Mutations
  module Roles
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "roles:create"

      graphql_name "CreateRole"
      description "Creates a new custom role"

      input_object_class Types::Roles::CreateInput

      type Types::RoleType

      def resolve(**args)
        result = ::Roles::CreateService.call(
          organization: current_organization,
          code: args[:code],
          name: args[:name],
          description: args[:description],
          permissions: args[:permissions]
        )

        result.success? ? result.role : result_error(result)
      end
    end
  end
end
