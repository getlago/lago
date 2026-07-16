# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuoteVersions::CreateService do
  subject(:create_service) do
    described_class.new(quote:, params: create_params)
  end

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:create_params) do
    {
      billing_items: {},
      content: "Test content",
      currency: "USD",
      start_date:,
      end_date:
    }
  end
  let(:start_date) { Date.new(2025, 2, 11) }
  let(:end_date) { Date.new(2025, 3, 12) }

  describe ".call" do
    let(:result) { create_service.call }

    context "when license is premium", :premium do
      it "creates draft quote version" do
        expect(result).to be_success
        expect(result.quote_version.quote_id).to eq(quote.id)
        expect(result.quote_version.organization_id).to eq(quote.organization_id)
        expect(result.quote_version.version).to eq(1)
        expect(result.quote_version.draft?).to eq(true)
        expect(result.quote_version.content).to eq("Test content")
        expect(result.quote_version.share_token).not_to be_nil
        expect(result.quote_version.billing_items).to eq({})
        expect(result.quote_version.currency).to eq("USD")
        expect(result.quote_version.start_date).to eq(start_date)
        expect(result.quote_version.end_date).to eq(end_date)
      end
    end

    context "when quote does not exist", :premium do
      let(:quote) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_not_found")
      end
    end

    context "when an active draft version already exists for the quote", :premium do
      before { create(:quote_version, quote:, organization:) }

      it "rejects with active_version_exists" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("active_version_exists")
      end
    end

    context "when an approved version already exists for the quote", :premium do
      before { create(:quote_version, :approved, quote:, organization:) }

      it "rejects with active_version_exists" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("active_version_exists")
      end
    end

    context "when a concurrent insert wins the unique-index race", :premium do
      it "translates the RecordNotUnique into active_version_exists" do
        allow(quote.versions).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("active_version_exists")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when feature flag is disabled", :premium do
      let(:organization) { create(:organization) }

      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
