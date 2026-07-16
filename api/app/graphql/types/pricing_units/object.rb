# frozen_string_literal: true

module Types
  module PricingUnits
    class Object < Types::BaseObject
      graphql_name "PricingUnit"

      field :id, ID, null: false

      field :code, String, null: false
      field :description, String, null: true
      field :name, String, null: false
      field :short_name, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
