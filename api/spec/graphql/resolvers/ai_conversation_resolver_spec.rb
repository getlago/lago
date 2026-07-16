# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::AiConversationResolver do
  let(:required_permission) { "ai_conversations:view" }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        aiConversation(id: $id) {
          id
          name
          mistralConversationId
          messages {
            content
            createdAt
            type
          }
          createdAt
          updatedAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:ai_conversation) { create(:ai_conversation, organization:, mistral_conversation_id: "conv_123") }
  let(:fetch_messages_service) { instance_double(AiConversations::FetchMessagesService) }
  let(:service_result) do
    result = BaseService::Result.new
    result.messages = [
      {
        "content" => "Hello",
        "created_at" => "2024-01-01T12:00:00Z",
        "type" => "message.output"
      },
      {
        "content" => "Hi there!",
        "created_at" => "2024-01-01T12:01:00Z",
        "type" => "message.output"
      }
    ]
    result
  end

  before do
    ai_conversation
    allow(AiConversations::FetchMessagesService).to receive(:call).and_return(service_result)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "ai_conversations:view"

  shared_examples "blocked feature" do |message|
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: ai_conversation.id}
      )

      expect_graphql_error(result:, message:)
    end
  end

  context "without premium feature" do
    it_behaves_like "blocked feature", "unauthorized"
  end

  context "without mistral configuration", :premium do
    before do
      ENV["MISTRAL_API_KEY"] = nil
      ENV["MISTRAL_AGENT_ID"] = nil
    end

    it_behaves_like "blocked feature", "feature_unavailable"
  end

  context "with premium feature", :premium do
    before do
      ENV["MISTRAL_API_KEY"] = "test_api_key"
      ENV["MISTRAL_AGENT_ID"] = "test_agent_id"
    end

    it "returns a single ai conversation with messages" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: ai_conversation.id}
      )

      ai_conversation_response = result["data"]["aiConversation"]

      expect(ai_conversation_response["id"]).to eq(ai_conversation.id)
      expect(ai_conversation_response["name"]).to eq(ai_conversation.name)
      expect(ai_conversation_response["mistralConversationId"]).to eq("conv_123")
      expect(ai_conversation_response["messages"].count).to eq(2)
      expect(ai_conversation_response["messages"][0]["content"]).to eq("Hello")
      expect(ai_conversation_response["messages"][0]["type"]).to eq("message.output")
      expect(ai_conversation_response["messages"][1]["content"]).to eq("Hi there!")
    end

    context "when ai conversation is not found" do
      it "returns an error" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {id: "foo"}
        )

        expect_graphql_error(result:, message: "Resource not found")
      end
    end

    context "when fetch messages service fails" do
      let(:failed_result) do
        result = BaseService::Result.new
        result.service_failure!(code: "mistral_api_error", message: "API error")
        result
      end

      before do
        allow(AiConversations::FetchMessagesService).to receive(:call).and_return(failed_result)
      end

      it "raises the error" do
        expect do
          execute_graphql(
            current_user: membership.user,
            current_organization: organization,
            permissions: required_permission,
            query:,
            variables: {id: ai_conversation.id}
          )
        end.to raise_error(BaseService::ServiceFailure)
      end
    end
  end
end
