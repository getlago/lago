# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::DunningCampaignFinishedSerializer do
  subject(:serializer) { described_class.new(customer, params) }

  let(:customer) { create(:customer) }
  let(:params) do
    {
      root_name: "dunning_campaign",
      dunning_campaign_code: "campaign_code"
    }
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["dunning_campaign"]["external_customer_id"]).to eq(customer.external_id)
    expect(result["dunning_campaign"]["dunning_campaign_code"]).to eq("campaign_code")
    expect(result["dunning_campaign"]["overdue_balance_cents"]).to eq(customer.overdue_balance_cents)
    expect(result["dunning_campaign"]["overdue_balance_currency"]).to eq(customer.currency)
    expect(result["dunning_campaign"]["overdue_balances"]).to eq([])

    # Deprecated fields that must be kept for backward compatibility
    expect(result["dunning_campaign"]["external_customer_id"]).to eq(customer.external_id)
  end

  context "when customer has overdue invoices in multiple currencies" do
    before do
      create(:invoice, customer:, payment_overdue: true, currency: "USD", total_amount_cents: 50_00)
      create(:invoice, customer:, payment_overdue: true, currency: "EUR", total_amount_cents: 30_00)
    end

    it "includes per-currency overdue_balances" do
      result = JSON.parse(serializer.to_json)

      expect(result["dunning_campaign"]["overdue_balances"]).to match_array([
        {"currency" => "USD", "amount_cents" => 50_00},
        {"currency" => "EUR", "amount_cents" => 30_00}
      ])
    end
  end
end
