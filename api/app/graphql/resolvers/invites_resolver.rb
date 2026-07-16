# frozen_string_literal: true

module Resolvers
  class InvitesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query pending invites of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    type Types::Invites::Object.collection_type, null: false

    def resolve(page: nil, limit: nil)
      current_organization
        .invites
        .pending
        .order(created_at: :desc)
        .page(page)
        .per(limit)
    end
  end
end
