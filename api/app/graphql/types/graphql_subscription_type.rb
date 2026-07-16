# frozen_string_literal: true

module Types
  class GraphqlSubscriptionType < Types::BaseObject
    field :ai_conversation_streamed, subscription: Types::GraphqlSubscriptions::AiConversation
  end
end
