# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::QuoteVersionsController do
  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:quote_version) { create(:quote_version, quote:, organization:) }

  describe "GET /api/v1/quote_versions/:id" do
    subject { get_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}") }

    let(:quote_version_id) { quote_version.id }

    before { quote_version }

    include_examples "requires API permission", "quote", "read"

    it "returns the quote version with full details" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:quote_version][:lago_id]).to eq(quote_version.id)
      expect(json[:quote_version][:lago_quote_id]).to eq(quote.id)
      expect(json[:quote_version][:status]).to eq("draft")
      expect(json[:quote_version][:version]).to eq(quote_version.version)
      expect(json[:quote_version].key?(:content)).to be(true)
      expect(json[:quote_version].key?(:share_token)).to be(false)
    end

    context "when the quote version does not exist" do
      let(:quote_version_id) { SecureRandom.uuid }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote_version")
      end
    end

    context "when the quote version belongs to another organization" do
      let(:quote_version) { create(:quote_version) }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote_version")
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

  describe "POST /api/v1/quote_versions/:id/approve" do
    subject { post_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}/approve") }

    let(:quote_version_id) { quote_version.id }

    before { quote_version }

    include_examples "requires API permission", "quote", "write"

    it "approves the quote version", :premium do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:quote_version][:lago_id]).to eq(quote_version.id)
      expect(json[:quote_version][:status]).to eq("approved")
    end

    context "with an expires_at in the future", :premium do
      subject do
        post_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}/approve", {expires_at:})
      end

      let(:expires_at) { 1.month.from_now.iso8601 }

      it "sets expires_at on the created order form" do
        subject

        expect(response).to have_http_status(:ok)
        expect(quote_version.reload.order_form.expires_at).to be_within(1.second).of(Time.zone.parse(expires_at))
      end
    end

    context "with an expires_at in the past", :premium do
      subject do
        post_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}/approve", {expires_at:})
      end

      let(:expires_at) { 1.day.ago.iso8601 }

      it "returns a validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(quote_version.reload.status).to eq("draft")
      end
    end

    context "when the quote version is not approvable", :premium do
      let(:quote_version) { create(:quote_version, :voided, quote:, organization:) }

      it "returns unprocessable entity" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the quote version does not exist", :premium do
      let(:quote_version_id) { SecureRandom.uuid }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote_version")
      end
    end

    context "without a premium license" do
      it "returns forbidden" do
        subject

        expect(response).to have_http_status(:forbidden)
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

  describe "POST /api/v1/quote_versions/:id/void" do
    subject { post_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}/void") }

    let(:quote_version_id) { quote_version.id }

    before { quote_version }

    include_examples "requires API permission", "quote", "write"

    it "voids the quote version", :premium do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:quote_version][:status]).to eq("voided")
      expect(json[:quote_version][:void_reason]).to eq("manual")
    end

    context "when the quote version is not voidable", :premium do
      let(:quote_version) { create(:quote_version, :approved, quote:, organization:) }

      it "returns unprocessable entity" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the quote version does not exist", :premium do
      let(:quote_version_id) { SecureRandom.uuid }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote_version")
      end
    end

    context "without a premium license" do
      it "returns forbidden" do
        subject

        expect(response).to have_http_status(:forbidden)
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

  describe "POST /api/v1/quote_versions/:id/clone" do
    subject { post_with_token(organization, "/api/v1/quote_versions/#{quote_version_id}/clone") }

    let(:quote_version_id) { quote_version.id }

    before { quote_version }

    include_examples "requires API permission", "quote", "write"

    it "clones the quote version into a new draft", :premium do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:quote_version][:status]).to eq("draft")
      expect(json[:quote_version][:lago_id]).not_to eq(quote_version.id)
    end

    context "when a different draft is the active version", :premium do
      let(:quote_version) do
        QuoteVersion.transaction do
          older = create(:quote_version, :voided, quote:, organization:)
          create(:quote_version, quote:, organization:)
          older
        end
      end

      it "clones the older version and voids the active draft" do
        active_draft = quote.versions.find_by(status: :draft)

        subject

        expect(response).to have_http_status(:ok)
        expect(json[:quote_version][:status]).to eq("draft")
        expect(json[:quote_version][:lago_id]).not_to eq(quote_version.id)
        expect(active_draft.reload.status).to eq("voided")
      end
    end

    context "when an approved version exists", :premium do
      let(:quote_version) { create(:quote_version, :approved, quote:, organization:) }

      it "returns unprocessable entity" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the quote version does not exist", :premium do
      let(:quote_version_id) { SecureRandom.uuid }

      it "returns not found" do
        subject

        expect(response).to be_not_found_error("quote_version")
      end
    end

    context "without a premium license" do
      it "returns forbidden" do
        subject

        expect(response).to have_http_status(:forbidden)
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
