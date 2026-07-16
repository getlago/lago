# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuoteVersions::UpdateService do
  subject(:update_service) { described_class.new(quote_version:, params: update_params) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:quote) { create(:quote, organization:) }
  let(:quote_version) { create(:quote_version, quote:, organization:) }
  let(:update_params) {
    {
      billing_items: {},
      content: "Test content",
      currency: "USD",
      start_date:,
      end_date:
    }
  }
  let(:start_date) { Date.new(2025, 2, 11) }
  let(:end_date) { Date.new(2025, 3, 12) }

  describe ".call" do
    let(:result) { update_service.call }

    context "when draft quote version", :premium do
      it "updates the quote version" do
        expect(result).to be_success
        expect(result.quote_version.id).to eq(quote_version.id)
        expect(result.quote_version.quote_id).to eq(quote_version.quote_id)
        expect(result.quote_version.organization_id).to eq(quote_version.organization_id)
        expect(result.quote_version.version).to eq(quote_version.version)
        expect(result.quote_version.draft?).to eq(true)
        expect(result.quote_version.billing_items).to eq({})
        expect(result.quote_version.content).to eq("Test content")
        expect(result.quote_version.currency).to eq("USD")
        expect(result.quote_version.start_date).to eq(start_date)
        expect(result.quote_version.end_date).to eq(end_date)
      end
    end

    context "when approved quote version", :premium do
      let(:quote_version) { create(:quote_version, :approved, quote:, organization:) }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({status: ["not_editable"]})
      end
    end

    context "when voided quote version", :premium do
      let(:quote_version) { create(:quote_version, :voided, quote:, organization:) }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({status: ["not_editable"]})
      end
    end

    context "when quote version does not exist", :premium do
      let(:quote_version) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_version_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
