# frozen_string_literal: true

module LagoMcpClient
  module Mistral
    class Agent
      MAX_ITERATIONS = 2

      attr_reader :conversation_id

      def initialize(client:, conversation_id:)
        @mistral_client = LagoMcpClient::Mistral::Client.new
        @mcp_context = LagoMcpClient::RunContext.new(client:)
        @conversation_id = conversation_id
        @mutex = Mutex.new
      end

      def setup!
        mcp_context.setup!
        self
      end

      def chat(user_message, max_tool_iterations: MAX_ITERATIONS)
        raise ArgumentError, "Block required for streaming" unless block_given?

        process_conversation(user_message, max_tool_iterations) { |chunk| yield chunk }
      end

      private

      attr_reader :mistral_client, :mcp_context, :mutex
      attr_writer :conversation_id

      def process_conversation(user_message, max_iterations)
        response = send_message(user_message) { |chunk| yield chunk }

        max_iterations.times do |i|
          break unless has_tool_calls?(response)

          tool_results = execute_tools(response["tool_calls"])
          response = send_tool_results(tool_results) { |chunk| yield chunk }
        end

        extract_final_content(response)
      end

      def send_message(message)
        if conversation_id
          mistral_client.append_to_conversation(
            conversation_id: conversation_id,
            inputs: [{role: "user", content: message}]
          ) { |chunk| yield chunk }
        else
          response = mistral_client.start_conversation(inputs: message) { |chunk| yield chunk }
          self.conversation_id = response["conversation_id"]
          response
        end
      end

      def send_tool_results(tool_results)
        inputs = tool_results.map do |result|
          {
            tool_call_id: result[:tool_call_id],
            result: result[:content],
            type: "function.result",
            object: "entry"
          }
        end

        mistral_client.append_to_conversation(
          conversation_id: conversation_id,
          inputs: inputs
        ) { |chunk| yield chunk }
      end

      def has_tool_calls?(response)
        response["tool_calls"]&.any?
      end

      def execute_tools(tool_calls)
        mcp_context.process_tool_calls(tool_calls).map do |result|
          {
            tool_call_id: result[:tool_call_id] || result["tool_call_id"],
            content: parse_tool_content(result[:content] || result["content"])
          }
        end
      end

      def parse_tool_content(content)
        parsed = JSON.parse(content)
        parsed.dig("content", 0, "text") || content
      rescue JSON::ParserError
        content.to_s
      end

      def extract_final_content(response)
        response.dig("outputs", 0, "content") || ""
      end
    end
  end
end
