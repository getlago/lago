# frozen_string_literal: true

module Resolvers
  class OrganizationResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query the current organization"

    type Types::Organizations::CurrentOrganizationType, null: true

    def resolve
      current_organization
    end
  end
end
