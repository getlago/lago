# frozen_string_literal: true

module Resolvers
  class InviteResolver < Resolvers::BaseResolver
    description "Query a single Invite"

    argument :token, String, required: true, description: "Uniq token of the Invite"

    type Types::Invites::Object, null: true

    def resolve(token:)
      invite = Invite.find_by(
        token:,
        status: "pending"
      )

      return not_found_error(resource: "invite") unless invite

      invite
    end
  end
end
