# frozen_string_literal: true

module Types
  module Invoices
    module Metadata
      class Object < Types::BaseObject
        description "Attributes for invoice metadata object"
        graphql_name "InvoiceMetadata"

        field :id, ID, null: false
        field :key, String, null: false
        field :value, String, null: false

        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      end
    end
  end
end
