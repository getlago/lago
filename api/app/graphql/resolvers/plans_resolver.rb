# frozen_string_literal: true

module Resolvers
  class PlansResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "plans:view"

    description "Query plans of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false
    argument :with_deleted, Boolean, required: false

    type Types::Plans::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, search_term: nil, with_deleted: nil)
      result = PlansQuery.call(
        organization: current_organization,
        search_term:,
        filters: {
          with_deleted:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.plans
    end
  end
end
