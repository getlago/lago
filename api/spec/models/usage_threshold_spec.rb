# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageThreshold do
  subject(:usage_threshold) { build(:usage_threshold) }

  it_behaves_like "paper_trail traceable"

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:plan).without_validating_presence
      expect(subject).to belong_to(:subscription).without_validating_presence
      expect(subject).to have_many(:applied_usage_thresholds)
      expect(subject).to have_many(:invoices).through(:applied_usage_thresholds)
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }

    describe "exactly_one_parent_present validation" do
      let(:organization) { create(:organization) }
      let(:plan) { create(:plan, organization:) }
      let(:subscription) { create(:subscription, organization:) }

      it "is valid when only plan_id is present" do
        threshold = build(:usage_threshold, organization:, plan:, subscription: nil)
        expect(threshold).to be_valid
      end

      it "is valid when only subscription_id is present" do
        threshold = build(:usage_threshold, organization:, plan: nil, subscription:)
        expect(threshold).to be_valid
      end

      it "is invalid when both plan_id and subscription_id are present" do
        threshold = build(:usage_threshold, organization:, plan:, subscription:)
        expect(threshold).not_to be_valid
        expect(threshold.errors[:base]).to eq(["one_of_plan_or_subscription_required"])
      end

      it "is invalid when neither plan_id nor subscription_id are present" do
        threshold = described_class.new(organization:, plan: nil, subscription: nil, amount_cents: 100)
        expect(threshold).not_to be_valid
        expect(threshold.errors[:base]).to include("one_of_plan_or_subscription_required")
      end
    end
  end

  describe "#currency" do
    let(:organization) { create(:organization, default_currency: "USD") }

    context "when threshold belongs to a plan" do
      let(:plan) { create(:plan, organization:, amount_currency: "GBP") }
      let(:threshold) { build(:usage_threshold, organization:, plan:, subscription: nil) }

      it "returns the plan amount_currency" do
        expect(threshold.currency).to eq("GBP")
      end
    end

    context "when threshold belongs to a subscription" do
      let(:plan) { create(:plan, organization:, amount_currency: "JPY") }
      let(:subscription) { create(:subscription, organization:, plan:) }
      let(:threshold) { build(:usage_threshold, organization:, plan: nil, subscription:) }

      it "returns the subscription plan amount_currency" do
        expect(threshold.currency).to eq("JPY")
      end
    end
  end

  describe "invoice_name" do
    subject(:usage_threshold) { build(:usage_threshold, threshold_display_name:) }

    let(:threshold_display_name) { "Threshold Display Name" }

    it { expect(usage_threshold.invoice_name).to eq(threshold_display_name) }

    context "when threshold display name is null" do
      let(:threshold_display_name) { nil }

      it { expect(usage_threshold.invoice_name).to eq(I18n.t("invoice.usage_threshold")) }
    end
  end
end
