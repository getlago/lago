# frozen_string_literal: true

module Resolvers
  class PricingUnitResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "pricing_units:view"

    argument :id, ID, required: true, description: "Uniq ID of the pricing unit"

    description "Query the pricing unit"

    type Types::PricingUnits::Object, null: false

    def resolve(id: nil)
      current_organization.pricing_units.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "pricing_unit")
    end
  end
end
