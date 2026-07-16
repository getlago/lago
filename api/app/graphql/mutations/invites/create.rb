# frozen_string_literal: true

module Mutations
  module Invites
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:members:create"

      graphql_name "CreateInvite"
      description "Creates a new Invite"

      argument :email, String, required: true
      argument :roles, [String], required: true

      type Types::Invites::Object

      def resolve(**args)
        result = ::Invites::CreateService.call(
          current_organization:,
          user: context[:current_user],
          email: args[:email],
          roles: args[:roles]
        )

        result.success? ? result.invite : result_error(result)
      end
    end
  end
end
