# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::AiConversationsResolver do
  let(:required_permission) { "ai_conversations:view" }
  let(:query) do
    <<~GQL
      query($limit: Int) {
        aiConversations(limit: $limit) {
          collection {
            id
            name
            mistralConversationId
            createdAt
            updatedAt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let!(:ai_conversation) { create(:ai_conversation, organization:, membership:, mistral_conversation_id: "conv_123") }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "ai_conversations:view"

  shared_examples "blocked feature" do |message|
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
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

    it "returns the list of ai conversations for the current user" do
      other_membership = create(:membership, organization:)
      create(:ai_conversation, organization:, membership: other_membership)

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {limit: 10}
      )

      ai_conversations_response = result["data"]["aiConversations"]["collection"]

      expect(ai_conversations_response.count).to eq(1)
      expect(ai_conversations_response.first["id"]).to eq(ai_conversation.id)
      expect(ai_conversations_response.first["name"]).to eq(ai_conversation.name)
      expect(ai_conversations_response.first["mistralConversationId"]).to eq("conv_123")
    end

    context "with limit parameter" do
      let(:ai_conversation2) { create(:ai_conversation, organization:, membership:) }
      let(:ai_conversation3) { create(:ai_conversation, organization:, membership:) }

      before do
        ai_conversation2
        ai_conversation3
      end

      it "limits the number of returned conversations" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {limit: 2}
        )

        ai_conversations_response = result["data"]["aiConversations"]["collection"]

        expect(ai_conversations_response.count).to eq(2)
      end
    end
  end
end
