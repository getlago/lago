# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Webhooks::Retry do
  let(:required_permission) { "developers:manage" }
  let(:webhook) { create(:webhook, :failed, webhook_endpoint:) }
  let(:webhook_endpoint) { create(:webhook_endpoint) }
  let(:organization) { webhook_endpoint.organization.reload }
  let(:membership) { create(:membership, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: RetryWebhookInput!) {
        retryWebhook(input: $input) {
          id,
        }
      }
    GQL
  end

  before { webhook }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  it "retries a webhook" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: webhook.id
        }
      }
    )

    result_data = result["data"]["retryWebhook"]

    expect(result_data["id"]).to eq(webhook.id)
  end
end
