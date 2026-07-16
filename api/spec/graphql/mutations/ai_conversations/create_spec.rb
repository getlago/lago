# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AiConversations::Create do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {input: {message: message}}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: CreateAiConversationInput!) {
        createAiConversation(input: $input) { id name }
      }
    GQL
  end

  let(:required_permission) { "ai_conversations:create" }
  let!(:membership) { create(:membership) }
  let(:message) { Faker::Lorem.word }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "ai_conversations:create"

  context "without premium feature" do
    it "returns an error" do
      expect_graphql_error(result:, message: "unauthorized")
    end
  end

  context "without mistral configuration", :premium do
    before do
      ENV["MISTRAL_API_KEY"] = nil
      ENV["MISTRAL_AGENT_ID"] = nil
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "feature_unavailable")
    end
  end

  context "with premium feature", :premium do
    before do
      ENV["MISTRAL_API_KEY"] = "test_api_key"
      ENV["MISTRAL_AGENT_ID"] = "test_agent_id"
    end

    it "creates a new AI conversation" do
      expect { result }.to change(AiConversation, :count).by(1)
      expect(result["data"]["createAiConversation"]["name"]).to eq(message)
    end

    it "triggers streaming" do
      expect { result }.to have_enqueued_job(AiConversations::StreamJob).with(
        ai_conversation: kind_of(AiConversation),
        message:
      ).on_queue("default")
    end
  end
end
