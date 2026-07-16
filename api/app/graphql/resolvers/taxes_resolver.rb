# frozen_string_literal: true

module Resolvers
  class TaxesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    description "Query taxes of an organization"

    argument :applied_to_organization, Boolean, required: false
    argument :auto_generated, Boolean, required: false
    argument :limit, Integer, required: false
    argument :order, String, required: false
    argument :page, Integer, required: false
    argument :search_term, String, required: false

    type Types::Taxes::Object.collection_type, null: false

    def resolve( # rubocop:disable Metrics/ParameterLists
      applied_to_organization: nil,
      auto_generated: nil,
      order: nil,
      page: nil,
      limit: nil,
      search_term: nil
    )
      result = ::TaxesQuery.call(
        organization: current_organization,
        search_term:,
        order:,
        pagination: {
          page:,
          limit:
        },
        filters: {
          applied_to_organization:,
          auto_generated:
        }
      )

      result.taxes
    end
  end
end
