# frozen_string_literal: true

module Types
  module AiConversations
    class Message < Types::BaseObject
      graphql_name "AiConversationMessage"

      field :content, String, null: false
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :type, String, null: false
    end
  end
end
