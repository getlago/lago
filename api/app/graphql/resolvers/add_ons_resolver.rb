# frozen_string_literal: true

module Resolvers
  class AddOnsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "addons:view"

    description "Query add-ons of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false

    type Types::AddOns::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, search_term: nil)
      result = ::AddOnsQuery.call(
        organization: current_organization,
        search_term:,
        pagination: {page:, limit:}
      )

      result.add_ons
    end
  end
end
