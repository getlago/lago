# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WebhookEndpointsResolver do
  let(:required_permission) { "developers:manage" }
  let(:query) do
    <<~GQL
      query {
        webhookEndpoints(limit: 5) {
          collection { id webhookUrl signatureAlgo name eventTypes }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  it "returns a list of webhook endpoints" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    webhook_endpoints_response = result["data"]["webhookEndpoints"]

    expect(webhook_endpoints_response["collection"].first).to include(
      "id" => organization.webhook_endpoints.first.id,
      "webhookUrl" => organization.webhook_endpoints.first.webhook_url,
      "signatureAlgo" => organization.webhook_endpoints.first.signature_algo,
      "name" => organization.webhook_endpoints.first.name,
      "eventTypes" => organization.webhook_endpoints.first.event_types
    )

    expect(webhook_endpoints_response["metadata"]).to include(
      "currentPage" => 1,
      "totalCount" => 1
    )
  end
end
