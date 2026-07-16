# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEndpoints::DestroyService do
  subject(:destroy_service) { described_class.new(webhook_endpoint:) }

  include_context "with mocked security logger"

  context "when endpoint exists" do
    # rubocop: disable RSpec/LetSetup
    let!(:webhook_endpoint) { create(:webhook_endpoint) }
    # rubocop: enable RSpec/LetSetup

    it "destroys the webhook endpoint" do
      expect { destroy_service.call }.to change(WebhookEndpoint, :count).by(-1)
    end

    it_behaves_like "produces a security log", "webhook_endpoint.deleted" do
      before { destroy_service.call }
    end
  end

  context "when webhook endpoint does not exist" do
    let(:webhook_endpoint) { nil }

    it "returns a not found error" do
      result = destroy_service.call

      expect(result).not_to be_success
      expect(result.error.message).to eq("webhook_endpoint_not_found")
    end

    it_behaves_like "does not produce a security log" do
      before { destroy_service.call }
    end
  end
end
