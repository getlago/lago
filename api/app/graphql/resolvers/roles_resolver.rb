# frozen_string_literal: true

module Resolvers
  class RolesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "roles:view"

    description "Query roles available for the organization"

    type [Types::RoleType], null: false

    def resolve
      Role
        .includes(active_memberships: :user)
        .where(organization_id: [nil, current_organization.id])
        .order("organization_id NULLS FIRST, LOWER(name)")
    end
  end
end
