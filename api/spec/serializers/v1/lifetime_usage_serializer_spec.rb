# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::LifetimeUsageSerializer do
  subject(:serializer) { described_class.new(lifetime_usage, root_name: "lifetime_usage", includes: %i[usage_thresholds]) }

  let(:lifetime_usage) { create(:lifetime_usage, organization:, subscription:, historical_usage_amount_cents:, invoiced_usage_amount_cents:, current_usage_amount_cents:) }
  let(:historical_usage_amount_cents) { 15 }
  let(:invoiced_usage_amount_cents) { 12 }
  let(:current_usage_amount_cents) { 18 }
  let(:subscription) { create(:subscription) }
  let(:organization) { subscription.organization }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)
    expect(result["lifetime_usage"]).to include(
      "lago_id" => lifetime_usage.id,
      "lago_subscription_id" => lifetime_usage.subscription.id,
      "external_subscription_id" => lifetime_usage.subscription.external_id,
      "external_historical_usage_amount_cents" => historical_usage_amount_cents,
      "invoiced_usage_amount_cents" => invoiced_usage_amount_cents,
      "current_usage_amount_cents" => current_usage_amount_cents
    )
  end

  context "with usage_thresholds in the plan" do
    let(:plan) { create(:plan) }
    let(:organization) { plan.organization }

    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, plan:, customer:) }
    let(:usage_threshold) { create(:usage_threshold, plan:, amount_cents: 100) }
    let(:usage_threshold2) { create(:usage_threshold, plan:, amount_cents: 200) }

    let(:applied_usage_threshold) { create(:applied_usage_threshold, lifetime_usage_amount_cents: 120, usage_threshold: usage_threshold, invoice:) }

    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

    let(:current_usage_amount_cents) { 120 }

    before do
      usage_threshold
      usage_threshold2
      invoice_subscription
      applied_usage_threshold
    end

    it "serializes the usage_thresholds" do
      result = JSON.parse(serializer.to_json)
      expect(result["lifetime_usage"]).to include(
        "lago_id" => lifetime_usage.id,
        "usage_thresholds" => [
          {"amount_cents" => 100, "completion_ratio" => 1.0, "reached_at" => applied_usage_threshold.created_at.iso8601(3)},
          {"amount_cents" => 200, "completion_ratio" => 0.47, "reached_at" => nil}
        ]
      )
    end
  end
end
