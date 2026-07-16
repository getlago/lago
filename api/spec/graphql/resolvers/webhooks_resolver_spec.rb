# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WebhooksResolver do
  let(:required_permission) { "developers:manage" }
  let(:query) do
    <<~GQL
      query {
        webhooks(limit: 5, webhookEndpointId: "#{webhook_endpoint.id}") {
          collection { id payload }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:webhook_endpoint) { create(:webhook_endpoint) }
  let(:organization) { webhook_endpoint.organization.reload }
  let(:membership) { create(:membership, organization:) }

  before do
    create_list(:webhook, 5, :succeeded, webhook_endpoint:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  it "returns a list of webhooks" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    webhooks_response = result["data"]["webhooks"]
    webhook = webhooks_response["collection"].first

    expect(webhooks_response["collection"].count).to eq(webhook_endpoint.webhooks.count)
    expect(webhooks_response["metadata"]["currentPage"]).to eq(1)
    expect(webhook["payload"]).to be_a String
    expect(JSON.parse(webhook["payload"])).to be_a Hash
  end

  context "when the webhook payload is json-serialized in the database" do
    it "returns a list of webhooks" do
      Webhook.all.find_each do |w|
        w.update_column(:payload, {"foo" => "bar"}.to_json) # rubocop:disable Rails/SkipsModelValidations
      end

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      webhooks_response = result["data"]["webhooks"]
      webhook = webhooks_response["collection"].first

      expect(webhooks_response["collection"].count).to eq(webhook_endpoint.webhooks.count)
      expect(webhooks_response["metadata"]["currentPage"]).to eq(1)
      expect(webhook["payload"]).to be_a String
      expect(JSON.parse(webhook["payload"])).to be_a Hash
    end
  end
end
