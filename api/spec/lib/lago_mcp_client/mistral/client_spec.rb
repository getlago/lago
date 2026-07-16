# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::Mistral::Client do
  subject(:client) { described_class.new }

  let(:http_client) { instance_double(LagoHttpClient::Client) }
  let(:api_key) { "test_api_key" }
  let(:agent_id) { "test_agent_id" }

  before do
    ENV["MISTRAL_API_KEY"] = api_key
    ENV["MISTRAL_AGENT_ID"] = agent_id
    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
  end

  describe "#start_conversation" do
    let(:inputs) { "Hello, how can I help?" }
    let(:conversation_id) { "conv_123" }

    before do
      allow(http_client).to receive(:post_with_stream).and_yield(
        nil,
        {conversation_id:, type: "conversation.response.done"}.to_json,
        nil,
        nil
      )
    end

    it "creates an HTTP client with the conversations URL and timeout" do
      client.start_conversation(inputs:)

      expect(LagoHttpClient::Client).to have_received(:new).with(
        "https://api.mistral.ai/v1/conversations",
        read_timeout: 120
      )
    end

    it "calls post_with_stream with correct payload and headers" do
      client.start_conversation(inputs:)

      expect(http_client).to have_received(:post_with_stream).with(
        {
          agent_id:,
          inputs: [{role: "user", content: inputs}],
          stream: true
        },
        {
          "Authorization" => "Bearer #{api_key}",
          "Accept" => "text/event-stream"
        }
      )
    end

    it "returns the parsed result" do
      result = client.start_conversation(inputs:)

      expect(result["conversation_id"]).to eq(conversation_id)
    end

    context "when inputs is an array" do
      let(:inputs) { [{role: "user", content: "Hello"}] }

      it "passes inputs as-is without normalizing" do
        client.start_conversation(inputs:)

        expect(http_client).to have_received(:post_with_stream).with(
          hash_including(inputs:),
          anything
        )
      end
    end

    context "when streaming content" do
      let(:chunks) { [] }

      before do
        allow(http_client).to receive(:post_with_stream)
          .and_yield(nil, {type: "message.output.delta", content: "Hello"}.to_json, nil, nil)
          .and_yield(nil, {type: "message.output.delta", content: " world"}.to_json, nil, nil)
          .and_yield(nil, {conversation_id:, type: "conversation.response.done"}.to_json, nil, nil)
      end

      it "yields content chunks to the block" do
        client.start_conversation(inputs:) { |chunk| chunks << chunk }

        expect(chunks).to eq(["Hello", " world"])
      end
    end

    context "when HTTP error occurs" do
      before do
        allow(http_client).to receive(:post_with_stream).and_raise(
          LagoHttpClient::HttpError.new(401, "Unauthorized", URI("https://api.mistral.ai"))
        )
      end

      it "raises ApiError with code and body" do
        expect { client.start_conversation(inputs:) }
          .to raise_error(LagoMcpClient::Mistral::ApiError) do |error|
            expect(error.error_code).to eq(401)
            expect(error.error_body).to eq("Unauthorized")
            expect(error.message).to eq("Mistral API Error (401): Unauthorized")
          end
      end
    end

    context "when other error occurs" do
      before do
        allow(http_client).to receive(:post_with_stream).and_raise(StandardError.new("Connection failed"))
      end

      it "raises a streaming error" do
        expect { client.start_conversation(inputs:) }
          .to raise_error("Mistral Conversations API streaming error: Connection failed")
      end
    end
  end

  describe "#append_to_conversation" do
    let(:conversation_id) { "conv_existing_789" }
    let(:inputs) { [{role: "user", content: "Follow-up question"}] }

    before do
      allow(http_client).to receive(:post_with_stream).and_yield(
        nil,
        {type: "conversation.response.done"}.to_json,
        nil,
        nil
      )
    end

    it "creates an HTTP client with the conversation-specific URL" do
      client.append_to_conversation(conversation_id:, inputs:)

      expect(LagoHttpClient::Client).to have_received(:new).with(
        "https://api.mistral.ai/v1/conversations/#{conversation_id}",
        read_timeout: 120
      )
    end

    it "calls post_with_stream with correct payload" do
      client.append_to_conversation(conversation_id:, inputs:)

      expect(http_client).to have_received(:post_with_stream).with(
        {inputs:, stream: true},
        {
          "Authorization" => "Bearer #{api_key}",
          "Accept" => "text/event-stream"
        }
      )
    end
  end
end
