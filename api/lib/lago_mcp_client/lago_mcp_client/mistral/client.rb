# frozen_string_literal: true

module LagoMcpClient
  module Mistral
    class ApiError < StandardError
      attr_reader :error_code, :error_body

      def initialize(error_code, error_body)
        @error_code = error_code
        @error_body = error_body
        super("Mistral API Error (#{error_code}): #{error_body}")
      end
    end

    class Client
      MISTRAL_CONVERSATIONS_URL = "https://api.mistral.ai/v1/conversations"

      def start_conversation(inputs:, &block)
        payload = {
          agent_id: ENV["MISTRAL_AGENT_ID"],
          inputs: normalize_inputs(inputs),
          stream: true
        }
        stream_conversation(payload, MISTRAL_CONVERSATIONS_URL, &block)
      end

      def append_to_conversation(conversation_id:, inputs:, &block)
        url = "#{MISTRAL_CONVERSATIONS_URL}/#{conversation_id}"
        payload = {inputs: inputs, stream: true}
        stream_conversation(payload, url, &block)
      end

      private

      def normalize_inputs(inputs)
        if inputs.is_a?(String)
          [{role: "user", content: inputs}]
        else
          inputs
        end
      end

      def stream_conversation(payload, url)
        http_client = LagoHttpClient::Client.new(url, read_timeout: 120)
        headers = {
          "Authorization" => "Bearer #{ENV["MISTRAL_API_KEY"]}",
          "Accept" => "text/event-stream"
        }

        parser = ResponseParser.new

        http_client.post_with_stream(payload, headers) do |_type, data, _id, _reconnection_time|
          parser.process(data) { |content| yield content if block_given? }
        end

        parser.to_result
      rescue LagoHttpClient::HttpError => e
        raise ApiError.new(e.error_code, e.error_body)
      rescue => e
        raise "Mistral Conversations API streaming error: #{e.message}"
      end
    end
  end
end
