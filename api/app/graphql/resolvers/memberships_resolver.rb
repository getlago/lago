# frozen_string_literal: true

module Resolvers
  class MembershipsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query memberships of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    type Types::MembershipType.collection_type(metadata_type: Types::Memberships::Metadata), null: false

    def resolve(page: nil, limit: nil)
      current_organization
        .memberships
        .includes(:user)
        .active
        .page(page)
        .per(limit)
    end
  end
end
