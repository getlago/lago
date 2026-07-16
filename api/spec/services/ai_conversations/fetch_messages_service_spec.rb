# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiConversations::FetchMessagesService do
  subject(:service) { described_class.new(ai_conversation:) }

  let(:ai_conversation) { create(:ai_conversation, mistral_conversation_id: "conv_123") }
  let(:http_client) { instance_double(LagoHttpClient::Client) }

  before do
    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
  end

  describe "#call" do
    let(:response_body) do
      {
        "messages" => [
          {
            "type" => "message.output",
            "content" => "Hello",
            "created_at" => "2024-01-01T12:00:00Z"
          },
          {
            "type" => "message.output",
            "content" => "Hi there!",
            "created_at" => "2024-01-01T12:01:00Z"
          }
        ]
      }
    end

    before do
      allow(http_client).to receive(:get).and_return(response_body)
    end

    it "fetches messages from Mistral API" do
      result = service.call

      expect(result).to be_success
      expect(result.messages).to eq(response_body["messages"])
      expect(http_client).to have_received(:get)
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("MISTRAL_API_KEY")}"})
    end

    context "when API request fails" do
      let(:http_error) do
        LagoHttpClient::HttpError.new(
          500,
          {message: "API error"}.to_json,
          URI("https://api.mistral.ai/v1/conversations/conv_123/messages")
        )
      end

      before do
        allow(http_client).to receive(:get).and_raise(http_error)
      end

      it "does not raise an error" do
        result = service.call

        expect(result).to be_success
        expect(result.error).to be_nil
      end
    end

    context "when conversation ID is missing" do
      let(:ai_conversation) { create(:ai_conversation, mistral_conversation_id: nil) }

      it "returns empty messages array" do
        result = service.call

        expect(result).to be_success
        expect(result.messages).to eq([])
      end
    end
  end
end
