# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::WebhookEndpointSerializer do
  subject(:serializer) { described_class.new(webhook_endpoint, root_name: "webhook_endpoint") }

  let(:webhook_endpoint) { create(:webhook_endpoint) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["webhook_endpoint"]["lago_organization_id"]).to eq(webhook_endpoint.organization_id)
    expect(result["webhook_endpoint"]["webhook_url"]).to eq(webhook_endpoint.webhook_url)
    expect(result["webhook_endpoint"]["created_at"]).to eq(webhook_endpoint.created_at.iso8601)
    expect(result["webhook_endpoint"]["signature_algo"]).to eq(webhook_endpoint.signature_algo)
    expect(result["webhook_endpoint"]["name"]).to eq(webhook_endpoint.name)
    expect(result["webhook_endpoint"]["event_types"]).to eq(webhook_endpoint.event_types)
  end
end
