# frozen_string_literal: true

module Resolvers
  class RoleResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "roles:view"

    description "Query a single role"

    argument :id, ID, required: true, description: "Uniq ID of the role"

    type Types::RoleType, null: true

    def resolve(id:)
      Role.with_organization(current_organization.id).find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "role")
    end
  end
end
