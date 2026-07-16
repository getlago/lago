# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Quotes::VersionsController do
  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:customer) { create(:customer, organization:) }

  describe "GET /api/v1/quotes/:quote_id/versions" do
    subject { get_with_token(organization, "/api/v1/quotes/#{quote_id}/versions", params) }

    let(:params) { {} }
    let(:quote_id) { quote.id }
    let!(:quote) { create(:quote, organization:, customer:) }
    let!(:voided_version) { create(:quote_version, :voided, quote:, organization:) }
    let!(:draft_version) { create(:quote_version, quote:, organization:) }

    include_examples "requires API permission", "quote", "read"

    it "returns the slim quote versions" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:quote_versions].count).to eq(2)
      expect(json[:quote_versions].map { |version| version[:lago_id] }).to match_array([voided_version.id, draft_version.id])
      expect(json[:quote_versions].first.keys).not_to include(:share_token, :content, :billing_items)
    end

    it "orders versions by sequential_id descending (newest first)" do
      subject

      expect(json[:quote_versions].map { |version| version[:lago_id] }).to eq([draft_version.id, voided_version.id])
    end

    it "returns canonical pagination meta" do
      subject

      expect(json[:meta]).to include(current_page: 1, total_pages: 1, total_count: 2)
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      it "returns paginated versions with meta data" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:quote_versions].count).to eq(1)
        expect(json[:meta]).to include(
          current_page: 1,
          next_page: 2,
          prev_page: nil,
          total_pages: 2,
          total_count: 2
        )
      end
    end

    context "when the quote does not exist" do
      let(:quote_id) { SecureRandom.uuid }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote")
      end
    end

    context "when the order_forms feature flag is disabled" do
      let(:organization) { create(:organization) }

      it "returns forbidden" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:code]).to eq("feature_unavailable")
      end
    end
  end
end
