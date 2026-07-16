# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WebhookResolver do
  let(:required_permission) { "developers:manage" }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        webhook(id: $id) {
          id endpoint status webhookType httpStatus payload response createdAt
        }
      }
    GQL
  end

  let(:webhook_endpoint) { create(:webhook_endpoint) }
  let(:webhook) { create(:webhook, :succeeded, webhook_endpoint:) }
  let(:organization) { webhook_endpoint.organization.reload }
  let(:membership) { create(:membership, organization:) }

  before { webhook }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:manage"

  it "returns a single webhook" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {id: webhook.id}
    )

    webhook_response = result["data"]["webhook"]
    expect(webhook_response["id"]).to eq(webhook.id)
    expect(webhook_response["endpoint"]).to eq(webhook.endpoint)
    expect(webhook_response["status"]).to eq(webhook.status)
    expect(webhook_response["webhookType"]).to eq(webhook.webhook_type)
    expect(webhook_response["payload"]).to be_a String
    expect(JSON.parse(webhook_response["payload"])).to be_a Hash
  end

  context "when webhook is not found" do
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

  context "when the webhook payload is json-serialized in the database" do
    before do
      webhook.update_column(:payload, {"foo" => "bar"}.to_json) # rubocop:disable Rails/SkipsModelValidations
    end

    it "returns the webhook with properly formatted payload" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: webhook.id}
      )

      webhook_response = result["data"]["webhook"]

      expect(webhook_response["payload"]).to be_a String
      expect(JSON.parse(webhook_response["payload"])).to eq({"foo" => "bar"})
    end
  end
end
