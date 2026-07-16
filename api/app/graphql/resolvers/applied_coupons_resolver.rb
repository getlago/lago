# frozen_string_literal: true

module Resolvers
  class AppliedCouponsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "coupons:view"

    description "Query applied coupons of an organization"

    argument :coupon_code, [String], required: false
    argument :external_customer_id, String, required: false
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :status, Types::AppliedCoupons::StatusEnum, required: false

    type Types::AppliedCoupons::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, status: nil, external_customer_id: nil, coupon_code: nil)
      result = AppliedCouponsQuery.call(
        organization: current_organization,
        pagination: {page:, limit:},
        filters: {
          status:,
          external_customer_id:,
          coupon_code:
        }
      )

      result.applied_coupons
    end
  end
end
