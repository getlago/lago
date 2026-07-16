# frozen_string_literal: true

module Types
  module Quotes
    class CreateInput < BaseInputObject
      graphql_name "CreateQuoteInput"

      argument :billing_items, GraphQL::Types::JSON, required: false
      argument :content, String, required: false
      argument :currency, String, required: false
      argument :customer_id, ID, required: true
      argument :end_date, GraphQL::Types::ISO8601Date, required: false
      argument :order_type, Types::Quotes::OrderTypeEnum, required: true
      argument :owners, [ID], required: false
      argument :start_date, GraphQL::Types::ISO8601Date, required: false
      argument :subscription_id, ID, required: false
    end
  end
end
