# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Wallets::MetadataController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:) }
  let(:wallet_id) { wallet.id }

  describe "POST /api/v1/wallets/:id/metadata" do
    it_behaves_like "a wallet metadata create endpoint" do
      subject { post_with_token(organization, "/api/v1/wallets/#{wallet_id}/metadata", metadata_params) }
    end
  end

  describe "PATCH /api/v1/wallets/:id/metadata" do
    it_behaves_like "a wallet metadata update endpoint" do
      subject { patch_with_token(organization, "/api/v1/wallets/#{wallet_id}/metadata", metadata_params) }
    end
  end

  describe "DELETE /api/v1/wallets/:id/metadata" do
    it_behaves_like "a wallet metadata destroy endpoint" do
      subject { delete_with_token(organization, "/api/v1/wallets/#{wallet_id}/metadata") }
    end
  end

  describe "DELETE /api/v1/wallets/:id/metadata/:key" do
    it_behaves_like "a wallet metadata destroy key endpoint" do
      subject { delete_with_token(organization, "/api/v1/wallets/#{wallet_id}/metadata/#{key}") }
    end
  end
end
