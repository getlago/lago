# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsage do
  subject(:lifetime_usage) { create(:lifetime_usage) }

  it { is_expected.to belong_to(:organization) }

  describe "default scope" do
    let!(:deleted_lifetime_usage) { create(:lifetime_usage, :deleted) }

    it "only returns non-deleted lifetime-usage objects" do
      expect(described_class.all).to eq([lifetime_usage])
      expect(described_class.unscoped.discarded).to eq([deleted_lifetime_usage])
    end
  end

  describe "Validations" do
    it "requires that current_usage_amount_cents is postive" do
      lifetime_usage.current_usage_amount_cents = -1
      expect(lifetime_usage).not_to be_valid

      lifetime_usage.current_usage_amount_cents = 1
      expect(lifetime_usage).to be_valid
    end

    it "requires that invoiced_usage_amount_cents is postive" do
      lifetime_usage.invoiced_usage_amount_cents = -1
      expect(lifetime_usage).not_to be_valid

      lifetime_usage.invoiced_usage_amount_cents = 1
      expect(lifetime_usage).to be_valid
    end

    it "requires that historical_usage_amount_cents is positive" do
      lifetime_usage.historical_usage_amount_cents = -1
      expect(lifetime_usage).not_to be_valid

      lifetime_usage.historical_usage_amount_cents = 0
      expect(lifetime_usage).to be_valid

      lifetime_usage.historical_usage_amount_cents = 1
      expect(lifetime_usage).to be_valid
    end
  end

  describe "#total_amount_cents" do
    it "returns the sum of the historical, invoiced, and current usage" do
      lifetime_usage.historical_usage_amount_cents = 100
      lifetime_usage.invoiced_usage_amount_cents = 200
      lifetime_usage.current_usage_amount_cents = 300

      expect(lifetime_usage.total_amount_cents).to eq(600)
    end
  end
end
