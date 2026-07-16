# frozen_string_literal: true

module Types
  module QuoteVersions
    class UpdateInput < BaseInputObject
      graphql_name "UpdateQuoteVersionInput"

      argument :billing_items, GraphQL::Types::JSON, required: false
      argument :content, String, required: false
      argument :currency, String, required: false
      argument :end_date, GraphQL::Types::ISO8601Date, required: false
      argument :id, ID, required: true
      argument :start_date, GraphQL::Types::ISO8601Date, required: false
    end
  end
end
