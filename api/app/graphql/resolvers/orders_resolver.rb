# frozen_string_literal: true

module Resolvers
  class OrdersResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "orders:view"

    description "Query orders"

    argument :customer_id, [ID], required: false
    argument :executed_at_from, GraphQL::Types::ISO8601DateTime, required: false
    argument :executed_at_to, GraphQL::Types::ISO8601DateTime, required: false
    argument :execution_mode, [Types::Orders::ExecutionModeEnum], required: false
    argument :limit, Integer, required: false
    argument :number, [String], required: false
    argument :order_form_number, [String], required: false
    argument :order_type, [Types::Quotes::OrderTypeEnum], required: false
    argument :owner_id, [ID], required: false
    argument :page, Integer, required: false
    argument :quote_number, [String], required: false
    argument :search_term, String, required: false
    argument :status, [Types::Orders::StatusEnum], required: false

    type Types::Orders::Object.collection_type, null: false

    def resolve( # rubocop:disable Metrics/ParameterLists
      customer_id: nil,
      executed_at_from: nil,
      executed_at_to: nil,
      execution_mode: nil,
      limit: nil,
      number: nil,
      order_form_number: nil,
      order_type: nil,
      owner_id: nil,
      page: nil,
      quote_number: nil,
      search_term: nil,
      status: nil
    )
      result = OrdersQuery.call(
        organization: current_organization,
        pagination: {page:, limit:},
        filters: {
          status:,
          order_type:,
          execution_mode:,
          customer_id:,
          number:,
          order_form_number:,
          quote_number:,
          owner_id:,
          executed_at_from:,
          executed_at_to:
        },
        search_term:
      )

      result.orders
    end
  end
end
