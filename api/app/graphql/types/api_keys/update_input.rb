# frozen_string_literal: true

module Types
  module ApiKeys
    class UpdateInput < Types::BaseInputObject
      graphql_name "UpdateApiKeyInput"

      argument :id, ID, required: true
      argument :name, String, required: false
      argument :permissions, GraphQL::Types::JSON, required: false
    end
  end
end
