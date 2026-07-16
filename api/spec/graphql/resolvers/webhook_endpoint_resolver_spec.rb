# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WebhookEndpointResolver do
  let(:required_permission) { "developers:manage" }
  let(:query) do
    <<-GQL
      query($webhookEndpointId: ID!) {
        webhookEndpoint(id: $webhookEndpointId) {
          id
          webhookUrl
          signatureAlgo
          name
          eventTypes
          createdAt
          updatedAt
          organization { id name }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:webhook_endpoint) { build(:webhook_endpoint, organization:, event_types: ["customer.created"]) }
  let(:organization) { membership.organization }

  before do
    organization.webhook_endpoints << webhook_endpoint
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  it "returns a single credit note" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        webhookEndpointId: webhook_endpoint.id
      }
    )

    webhook_endpoint_response = result["data"]["webhookEndpoint"]

    expect(webhook_endpoint_response["id"]).to eq(webhook_endpoint.id)
    expect(webhook_endpoint_response["webhookUrl"]).to eq(webhook_endpoint.webhook_url)
    expect(webhook_endpoint_response["signatureAlgo"]).to eq(webhook_endpoint.signature_algo)
    expect(webhook_endpoint_response["name"]).to eq(webhook_endpoint.name)
    expect(webhook_endpoint_response["eventTypes"]).to match_array(["customer_created"])
    expect(webhook_endpoint_response["createdAt"]).to eq(webhook_endpoint.created_at.iso8601)
    expect(webhook_endpoint_response["updatedAt"]).to eq(webhook_endpoint.updated_at.iso8601)
    expect(webhook_endpoint_response["organization"]["id"]).to eq(organization.id)
    expect(webhook_endpoint_response["organization"]["name"]).to eq(organization.name)
  end
end
