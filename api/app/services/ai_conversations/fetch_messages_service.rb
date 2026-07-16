# frozen_string_literal: true

module AiConversations
  class FetchMessagesService < BaseService
    Result = BaseResult[:messages]
    MISTRAL_CONVERSATIONS_API_URL = "https://api.mistral.ai/v1/conversations"

    def initialize(ai_conversation:)
      @ai_conversation = ai_conversation
      @http = LagoHttpClient::Client.new(api_url)

      super
    end

    def call
      result.messages = []
      return result if ai_conversation.mistral_conversation_id.blank?

      http_result = @http.get(headers:)
      messages = http_result["messages"].map { |h| h.slice("content", "created_at", "type") }

      result.messages = messages
      result
    rescue LagoHttpClient::HttpError => e
      Rails.logger.error("Error fetching Mistral messages: #{e.message}")
      result
    end

    private

    attr_reader :ai_conversation

    def api_url
      "#{MISTRAL_CONVERSATIONS_API_URL}/#{ai_conversation.mistral_conversation_id}/messages"
    end

    def headers
      {
        "Authorization" => "Bearer #{ENV.fetch("MISTRAL_API_KEY")}"
      }
    end
  end
end
