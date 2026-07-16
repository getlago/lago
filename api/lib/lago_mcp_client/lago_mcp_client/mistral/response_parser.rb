# frozen_string_literal: true

module LagoMcpClient
  module Mistral
    class ResponseParser
      attr_reader :conversation_id, :outputs, :tool_calls

      def initialize
        @conversation_id = nil
        @outputs = []
        @tool_calls = []
      end

      # Processes a single SSE data chunk and updates internal state.
      # Yields message content to the block for streaming output.
      def process(data, &block)
        return if data == "[DONE]"

        parsed_data = JSON.parse(data)
        @conversation_id ||= parsed_data["conversation_id"]

        dispatch_event(parsed_data, &block)
        extract_outputs(parsed_data["outputs"])
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse SSE data: #{data[0..200]}")
        Rails.logger.error("Parse error: #{e.message}")
      end

      # Returns the accumulated conversation result.
      def to_result
        {
          "conversation_id" => conversation_id,
          "outputs" => outputs,
          "tool_calls" => tool_calls.empty? ? nil : tool_calls
        }
      end

      private

      # Routes events to appropriate processors based on event type.
      def dispatch_event(parsed_data, &block)
        case parsed_data["type"]
        when "message.output.delta"
          stream_content(parsed_data, &block)
        when "conversation.response.done"
          @conversation_id ||= parsed_data["conversation_id"]
        when "function.call", "function.call.delta"
          accumulate_tool_call(parsed_data)
        end
      end

      # Yields streamed content to the caller for real-time output.
      def stream_content(parsed_data)
        content = parsed_data["content"]
        yield content if content.present? && block_given?
      end

      # Accumulates function call data, merging arguments for streaming deltas.
      def accumulate_tool_call(parsed_data)
        tool_call_id = parsed_data["tool_call_id"]
        existing = tool_calls.find { |tc| tc["id"] == tool_call_id }

        if existing
          existing["function"]["arguments"] = (existing["function"]["arguments"] || "") + (parsed_data["arguments"] || "")
        else
          tool_calls << build_tool_call(
            id: tool_call_id,
            name: parsed_data["name"],
            arguments: parsed_data["arguments"] || ""
          )
        end
      end

      # Extracts final outputs and tool calls from the outputs array.
      def extract_outputs(outputs_array)
        return unless outputs_array

        outputs_array.each do |output|
          case output["type"]
          when "message.output"
            outputs << output
          when "tool.call", "function.call"
            tool_calls << build_tool_call(
              id: output["tool_call_id"] || output["id"],
              name: output["name"] || output.dig("function", "name"),
              arguments: output["arguments"] || output.dig("function", "arguments")
            )
          end
        end
      end

      def build_tool_call(id:, name:, arguments:)
        {
          "id" => id,
          "type" => "function",
          "function" => {
            "name" => name,
            "arguments" => arguments
          }
        }
      end
    end
  end
end
