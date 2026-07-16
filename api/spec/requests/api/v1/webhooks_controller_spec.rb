# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::WebhooksController do
  let(:organization) { create(:organization) }

  describe "GET /api/v1/webhooks/public_key" do
    subject { get_with_token(organization, "/api/v1/webhooks/public_key") }

    include_examples "requires API permission", "webhook_jwt_public_key", "read"

    it "returns the public key used to verify webhook signatures" do
      subject

      expect(response).to have_http_status(:success)
      expect(response.body).to eq(Base64.encode64(RsaPublicKey.to_s))
    end
  end

  describe "GET /api/v1/webhooks/json_public_key" do
    subject { get_with_token(organization, "/api/v1/webhooks/json_public_key") }

    include_examples "requires API permission", "webhook_jwt_public_key", "read"

    it "returns the public key in JSON response used to verify webhook signatures" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:webhook][:public_key]).to eq(Base64.encode64(RsaPublicKey.to_s))
    end
  end
end
