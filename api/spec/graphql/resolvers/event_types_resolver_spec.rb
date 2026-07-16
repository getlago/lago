# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::EventTypesResolver do
  let(:required_permission) { "developers:manage" }
  let(:user) { create(:user) }
  let(:query) do
    <<~GQL
      query {
        eventTypes { name description category deprecated key }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "developers:manage"

  it "returns all supported event types" do
    result = execute_graphql(
      current_user: user,
      permissions: required_permission,
      query:
    )

    event_types_response = result["data"]["eventTypes"].map { |event_type| event_type["name"] }
    expect(event_types_response).to match_array(WebhookEndpoint::WEBHOOK_EVENT_TYPES)
  end
end
