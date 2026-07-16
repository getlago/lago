# frozen_string_literal: true

module Types
  module ApiKeys
    class RotateInput < Types::BaseInputObject
      graphql_name "RotateApiKeyInput"

      argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :id, ID, required: true
      argument :name, String, required: false
    end
  end
end
