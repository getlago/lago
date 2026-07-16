# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::WebhookEndpoints::Update do
  include_context "with mocked security logger"

  let(:required_permission) { "developers:manage" }
  let(:membership) { create(:membership) }
  let(:webhook_url) { Faker::Internet.url }
  let(:webhook_endpoint) { create(:webhook_endpoint, organization: membership.organization) }

  let(:input) do
    {
      id: webhook_endpoint.id,
      webhookUrl: webhook_url,
      signatureAlgo: "hmac",
      name: "Updated Webhook",
      eventTypes: ["customer_updated"]
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: WebhookEndpointUpdateInput!) {
        updateWebhookEndpoint(input: $input) {
          id,
          webhookUrl,
          signatureAlgo,
          name,
          eventTypes
        }
      }
    GQL
  end

  before { webhook_endpoint }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  context "with valid input" do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )
    end

    it "updates a webhook_endpoint" do
      expect(result["data"]["updateWebhookEndpoint"]).to include(
        "id" => String,
        "webhookUrl" => webhook_url,
        "signatureAlgo" => "hmac",
        "name" => "Updated Webhook",
        "eventTypes" => ["customer_updated"]
      )
    end

    it_behaves_like "produces a security log", "webhook_endpoint.updated"
  end
end
