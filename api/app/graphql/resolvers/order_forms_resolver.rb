# frozen_string_literal: true

module Resolvers
  class OrderFormsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "order_forms:view"

    description "Query order forms"

    argument :created_at_from, GraphQL::Types::ISO8601DateTime, required: false
    argument :created_at_to, GraphQL::Types::ISO8601DateTime, required: false
    argument :customer_id, [ID], required: false
    argument :expires_at_from, GraphQL::Types::ISO8601DateTime, required: false
    argument :expires_at_to, GraphQL::Types::ISO8601DateTime, required: false
    argument :limit, Integer, required: false
    argument :number, [String], required: false
    argument :owner_id, [ID], required: false
    argument :page, Integer, required: false
    argument :quote_number, [String], required: false
    argument :search_term, String, required: false
    argument :status, [Types::OrderForms::StatusEnum], required: false

    type Types::OrderForms::Object.collection_type, null: false

    def resolve( # rubocop:disable Metrics/ParameterLists
      created_at_from: nil,
      created_at_to: nil,
      expires_at_from: nil,
      expires_at_to: nil,
      customer_id: nil,
      limit: nil,
      number: nil,
      owner_id: nil,
      page: nil,
      quote_number: nil,
      search_term: nil,
      status: nil
    )
      result = OrderFormsQuery.call(
        organization: current_organization,
        pagination: {page:, limit:},
        filters: {
          status:,
          customer_id:,
          number:,
          quote_number:,
          owner_id:,
          created_at_from:,
          created_at_to:,
          expires_at_from:,
          expires_at_to:
        },
        search_term:
      )

      return result_error(result) unless result.success?

      result.order_forms
    end
  end
end
