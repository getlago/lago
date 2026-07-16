# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::FindLastAndNextThresholdsService do
  subject(:lifetime_usage_result) { described_class.call(lifetime_usage:) }

  let(:lifetime_usage) { create(:lifetime_usage, subscription:, organization:, current_usage_amount_cents:) }
  let(:current_usage_amount_cents) { 0 }

  let(:plan) { create(:plan) }
  let(:organization) { plan.organization }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, plan:, customer:) }

  it "computes the amounts" do
    expect(lifetime_usage_result.last_threshold_amount_cents).to be_nil
    expect(lifetime_usage_result.next_threshold_amount_cents).to be_nil
    expect(lifetime_usage_result.next_threshold_ratio).to be_nil
  end

  context "with a usage_threshold" do
    let(:usage_threshold) { create(:usage_threshold, plan:, amount_cents: 100) }

    before { usage_threshold }

    it "computes the amounts" do
      expect(lifetime_usage_result.last_threshold_amount_cents).to be_nil
      expect(lifetime_usage_result.next_threshold_amount_cents).to eq(100)
      expect(lifetime_usage_result.next_threshold_ratio).to be_zero
    end

    context "with a lifetime_usage" do
      let(:current_usage_amount_cents) { 23 }

      it "computes the amounts" do
        expect(lifetime_usage_result.last_threshold_amount_cents).to be_nil
        expect(lifetime_usage_result.next_threshold_amount_cents).to eq(100)
        expect(lifetime_usage_result.next_threshold_ratio).to eq(0.23)
      end
    end
  end

  context "with a past threshold" do
    let(:usage_threshold1) { create(:usage_threshold, plan:, amount_cents: 100) }
    let(:usage_threshold2) { create(:usage_threshold, plan:, amount_cents: 200) }

    let(:applied_usage_threshold) { create(:applied_usage_threshold, usage_threshold: usage_threshold1, invoice:) }

    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

    let(:current_usage_amount_cents) { 120 }

    before do
      usage_threshold1
      usage_threshold2

      invoice_subscription
      applied_usage_threshold
    end

    it "computes the amounts" do
      expect(lifetime_usage_result.last_threshold_amount_cents).to eq(100)
      expect(lifetime_usage_result.next_threshold_amount_cents).to eq(200)
      expect(lifetime_usage_result.next_threshold_ratio).to eq(0.2)
    end

    context "when lifetime_usage is above last threshold" do
      let(:applied_usage_threshold) { create(:applied_usage_threshold, usage_threshold: usage_threshold2, invoice:) }
      let(:current_usage_amount_cents) { 223 }

      it "computes the amounts" do
        expect(lifetime_usage_result.last_threshold_amount_cents).to eq(200)
        expect(lifetime_usage_result.next_threshold_amount_cents).to be_nil
        expect(lifetime_usage_result.next_threshold_ratio).to be_nil
      end
    end

    context "when next threshold is recurring" do
      let(:usage_threshold2) { create(:usage_threshold, :recurring, plan:, amount_cents: 200) }

      it "computes the amounts" do
        expect(lifetime_usage_result.last_threshold_amount_cents).to eq(100)
        expect(lifetime_usage_result.next_threshold_amount_cents).to eq(300)
        expect(lifetime_usage_result.next_threshold_ratio).to eq(0.1)
      end

      context "when lifetime_usage is above next threshold" do
        let(:applied_usage_threshold) { create(:applied_usage_threshold, usage_threshold: usage_threshold2, invoice:) }
        let(:current_usage_amount_cents) { 723 }

        it "computes the amounts" do
          expect(lifetime_usage_result.last_threshold_amount_cents).to eq(700)
          expect(lifetime_usage_result.next_threshold_amount_cents).to eq(900)
          expect(lifetime_usage_result.next_threshold_ratio).to eq(0.115) # (723 - 700) / 200
        end
      end
    end
  end
end
