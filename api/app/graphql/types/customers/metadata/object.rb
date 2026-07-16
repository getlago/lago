# frozen_string_literal: true

module Types
  module Customers
    module Metadata
      class Object < Types::BaseObject
        graphql_name "CustomerMetadata"

        field :display_in_invoice, Boolean, null: false
        field :id, ID, null: false
        field :key, String, null: false
        field :value, String, null: false

        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      end
    end
  end
end
