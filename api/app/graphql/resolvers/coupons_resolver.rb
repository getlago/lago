# frozen_string_literal: true

module Resolvers
  class CouponsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "coupons:view"

    description "Query coupons of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false
    argument :status, Types::Coupons::StatusEnum, required: false

    type Types::Coupons::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, status: nil, search_term: nil)
      result = CouponsQuery.call(
        organization: current_organization,
        search_term:,
        filters: {
          status:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.coupons
    end
  end
end
