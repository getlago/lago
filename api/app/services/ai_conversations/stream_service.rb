# frozen_string_literal: true

module AiConversations
  class StreamService < BaseService
    Result = BaseResult[:ai_conversation]
    CHUNK_DELAY = 0.03

    def initialize(ai_conversation:, message:)
      @ai_conversation = ai_conversation
      @message = message

      super
    end

    def call
      return result.forbidden_failure! if mcp_server_url.blank?

      setup_clients!
      stream_response
      save_conversation_id!
      notify_completion
      result.ai_conversation = ai_conversation
      result
    rescue => e
      handle_error(e)
    end

    private

    attr_reader :ai_conversation, :message

    def setup_clients!
      mcp_client.setup!
      mistral_agent.setup!
    end

    def stream_response
      mistral_agent.chat(message) do |chunk|
        next if chunk.nil?

        trigger_subscription(chunk:, done: false)
        sleep CHUNK_DELAY
      end
    end

    def save_conversation_id!
      return if mistral_agent.conversation_id.blank?
      return if ai_conversation.mistral_conversation_id == mistral_agent.conversation_id

      ai_conversation.update!(mistral_conversation_id: mistral_agent.conversation_id)
    end

    def notify_completion
      trigger_subscription(chunk: nil, done: true)
    end

    def trigger_subscription(chunk:, done:)
      LagoApiSchema.subscriptions.trigger(
        :ai_conversation_streamed,
        {id: ai_conversation.id},
        {chunk:, done:}
      )
    rescue => e
      Rails.logger.error("Failed to trigger subscription: #{e.message}")
    end

    def handle_error(error)
      Rails.logger.error("StreamService error: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))

      trigger_subscription(chunk: "Error: #{error.message}", done: true)
      result.service_failure!(code: "stream_service_error", message: error.message)
    end

    def mcp_server_url
      @mcp_server_url ||= ENV["LAGO_MCP_SERVER_URL"]
    end

    def mcp_client
      @mcp_client ||= LagoMcpClient::Client.new(mcp_client_config)
    end

    def mcp_client_config
      @mcp_client_config ||= LagoMcpClient::Config.new(mcp_server_url:, lago_api_key:)
    end

    def mistral_agent
      @mistral_agent ||= LagoMcpClient::Mistral::Agent.new(
        client: mcp_client,
        conversation_id: ai_conversation.mistral_conversation_id
      )
    end

    def lago_api_key
      @lago_api_key ||= ai_conversation.organization.api_keys.with_most_permissions.value
    end
  end
end
