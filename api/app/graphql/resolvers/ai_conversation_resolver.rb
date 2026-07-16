# frozen_string_literal: true

module Resolvers
  class AiConversationResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "ai_conversations:view"

    description "Query a single ai conversation of an organization"

    argument :id, ID, required: true, description: "Uniq ID of the ai conversation"

    type Types::AiConversations::ObjectWithMessages, null: true

    def resolve(id:)
      raise unauthorized_error unless License.premium?
      raise forbidden_error(code: "feature_unavailable") if ENV["MISTRAL_API_KEY"].blank? || ENV["MISTRAL_AGENT_ID"].blank?

      ai_conversation = current_organization.ai_conversations.find(id)
      result = ::AiConversations::FetchMessagesService.call(ai_conversation:).raise_if_error!

      ai_conversation.attributes.symbolize_keys.merge(
        messages: result.messages
      )
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "ai_conversation")
    end
  end
end
