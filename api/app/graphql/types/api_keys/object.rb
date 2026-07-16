# frozen_string_literal: true

module Types
  module ApiKeys
    class Object < Types::BaseObject
      graphql_name "ApiKey"

      field :id, ID, null: false
      field :name, String, null: true
      field :permissions, GraphQL::Types::JSON, null: false
      field :value, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
      field :last_used_at, GraphQL::Types::ISO8601DateTime, null: true
    end
  end
end
