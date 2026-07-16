# frozen_string_literal: true

module Resolvers
  class QuotesResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "quotes:view"

    description "Query quotes of an organization"

    argument :customers, [ID], required: false
    argument :from_date, GraphQL::Types::ISO8601Date, required: false
    argument :limit, Integer, required: false
    argument :numbers, [String], required: false
    argument :order_types, [Types::Quotes::OrderTypeEnum], required: false
    argument :owners, [ID], required: false
    argument :page, Integer, required: false
    argument :statuses, [Types::QuoteVersions::StatusEnum], required: false
    argument :to_date, GraphQL::Types::ISO8601Date, required: false

    type Types::Quotes::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, customers: nil, numbers: nil, statuses: nil, from_date: nil, to_date: nil, owners: nil, order_types: nil)
      result = ::QuotesQuery.call(
        organization: current_organization,
        filters: {
          customers:,
          statuses:,
          numbers:,
          from_date:,
          to_date:,
          owners:,
          order_types:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.success? ? result.quotes : result_error(result)
    end
  end
end
