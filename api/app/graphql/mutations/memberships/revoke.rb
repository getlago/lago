# frozen_string_literal: true

module Mutations
  module Memberships
    class Revoke < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:members:update"

      graphql_name "RevokeMembership"
      description "Revoke a membership"

      argument :id, ID, required: true

      type Types::MembershipType

      def resolve(id:)
        membership = current_organization.memberships.find_by(id: id)
        result = ::Memberships::RevokeService.call(user: context[:current_user], membership:)

        result.success? ? result.membership : result_error(result)
      end
    end
  end
end
