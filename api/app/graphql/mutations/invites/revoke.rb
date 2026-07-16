# frozen_string_literal: true

module Mutations
  module Invites
    class Revoke < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:members:delete"

      graphql_name "RevokeInvite"
      description "Revokes an invite"

      argument :id, ID, required: true

      type Types::Invites::Object

      def resolve(id:)
        invite = current_organization.invites.pending.find_by(id:, status: :pending)
        result = ::Invites::RevokeService.call(invite)

        result.success? ? result.invite : result_error(result)
      end
    end
  end
end
