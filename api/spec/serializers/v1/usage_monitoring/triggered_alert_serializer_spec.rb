# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::UsageMonitoring::TriggeredAlertSerializer do
  subject(:serializer) { described_class.new(triggered_alert, root_name: "triggered_alert") }

  let(:triggered_alert) { create(:triggered_alert, alert:, subscription:, triggered_at: DateTime.new(2000, 1, 1, 12, 0, 0)) }
  let(:subscription) { create(:subscription, external_id: "ext-id", customer: create(:customer, external_id: "cust-ext-id")) }

  before { triggered_alert }

  context "with usage_amount alert" do
    let(:alert) { create(:usage_current_amount_alert, subscription_external_id: "ext-id", code: "first") }

    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      payload = result["triggered_alert"]
      expect(payload["lago_id"]).to eq(triggered_alert.id)
      expect(payload["lago_organization_id"]).to eq(triggered_alert.organization_id)
      expect(payload["lago_alert_id"]).to eq(triggered_alert.alert.id)
      expect(payload["lago_subscription_id"]).to eq(triggered_alert.subscription.id)
      expect(payload["external_subscription_id"]).to eq("ext-id")
      expect(payload["lago_wallet_id"]).to be_nil
      expect(payload["external_customer_id"]).to eq("cust-ext-id")
      expect(payload["billable_metric_code"]).to be_nil
      expect(payload["alert_name"]).to eq("General Alert")
      expect(payload["alert_code"]).to eq("first")
      expect(payload["alert_type"]).to eq("current_usage_amount")
      expect(payload["current_value"]).to eq("3000.0")
      expect(payload["previous_value"]).to eq("1000.0")
      expect(payload["crossed_thresholds"]).to eq([
        {"code" => "warn", "value" => "2000.0", "recurring" => false},
        {"code" => "repeat", "value" => "2500.0", "recurring" => true}
      ])
      expect(payload["triggered_at"]).to eq("2000-01-01T12:00:00Z")

      # Deprecated fields that must be kept for backward compatibility
      expect(payload["subscription_external_id"]).to eq("ext-id")
      expect(payload["customer_external_id"]).to eq("cust-ext-id")
    end
  end

  context "with billable_metric_current_usage_amount alert" do
    let(:alert) { create(:billable_metric_current_usage_amount_alert, subscription_external_id: "ext-id") }

    it "has the billable_metric_id the object" do
      result = JSON.parse(serializer.to_json)

      payload = result["triggered_alert"]
      expect(payload["billable_metric_code"]).to eq alert.billable_metric.code
    end

    context "when billable_metric and alert are deleted" do
      it "retrieves the alert correctly" do
        alert.billable_metric.discard!
        alert.discard!
        triggered_alert.reload
        result = JSON.parse(serializer.to_json)
        payload = result["triggered_alert"]
        expect(payload["lago_alert_id"]).to eq alert.id
        expect(payload["billable_metric_code"]).to eq alert.billable_metric.code
      end
    end
  end

  context "with wallet_balance_amount alert" do
    let(:customer) { create(:customer, external_id: "wallet-cust-ext-id") }
    let(:wallet) { create(:wallet, customer:, organization: customer.organization) }
    let(:alert) { create(:wallet_balance_amount_alert, wallet:, organization: wallet.organization, code: "wallet-alert") }
    let(:triggered_alert) do
      create(:triggered_alert, alert:, subscription: nil, wallet:, triggered_at: DateTime.new(2000, 1, 1, 12, 0, 0))
    end

    it "serializes the wallet triggered alert" do
      result = JSON.parse(serializer.to_json)

      payload = result["triggered_alert"]
      expect(payload["lago_id"]).to eq(triggered_alert.id)
      expect(payload["lago_subscription_id"]).to be_nil
      expect(payload["external_subscription_id"]).to be_nil
      expect(payload["lago_wallet_id"]).to eq(wallet.id)
      expect(payload["external_customer_id"]).to eq("wallet-cust-ext-id")
      expect(payload["alert_type"]).to eq("wallet_balance_amount")
      expect(payload["alert_code"]).to eq("wallet-alert")
    end
  end
end
