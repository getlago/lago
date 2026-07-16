# frozen_string_literal: true

module Resolvers
  class PricingUnitsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "pricing_units:view"

    description "Query the pricing units of current organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false

    type Types::PricingUnits::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, search_term: nil)
      result = ::PricingUnitsQuery.call(
        organization: current_organization,
        search_term:,
        pagination: {page:, limit:}
      )

      result.pricing_units
    end
  end
end
