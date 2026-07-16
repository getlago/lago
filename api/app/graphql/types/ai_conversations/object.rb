# frozen_string_literal: true

module Types
  module AiConversations
    class Object < Types::BaseObject
      graphql_name "AiConversation"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType, null: false

      field :mistral_conversation_id, String
      field :name, String, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
