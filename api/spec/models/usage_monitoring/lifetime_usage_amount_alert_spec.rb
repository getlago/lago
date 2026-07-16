# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::LifetimeUsageAmountAlert do
  describe "#find_value" do
    subject { alert.find_value(lifetime_usage) }

    let(:alert) { build_stubbed(:lifetime_usage_amount_alert, subscription_external_id: "test") }
    let(:lifetime_usage) { build(:lifetime_usage, invoiced_usage_amount_cents: 6, current_usage_amount_cents: 3) }

    it "returns lifetime usage's total amount cents" do
      expect(subject).to eq(9)
    end
  end
end
