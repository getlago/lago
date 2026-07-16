# frozen_string_literal: true

module Resolvers
  class CouponResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "coupons:view"

    description "Query a single coupon of an organization"

    argument :id, ID, required: true, description: "Uniq ID of the coupon"

    type Types::Coupons::Object, null: true

    def resolve(id: nil)
      current_organization.coupons.with_discarded.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "coupon")
    end
  end
end
