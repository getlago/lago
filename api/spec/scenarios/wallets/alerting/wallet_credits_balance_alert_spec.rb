# frozen_string_literal: true

require "rails_helper"

describe "Wallet Credits Balance Alerts", :premium, transaction: false do
  include_context "with webhook tracking"

  let(:organization) { create(:organization, webhook_url: "https://example.com") }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "amount") }
  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  # Pay-in-advance charge creates invoices immediately and deducts from wallet
  let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, properties: {amount: "1"}) }

  def send_event!(subscription, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric.field_name => amount}
    })
    perform_usage_update
  end

  before { charge }

  describe "credits balance threshold crossing with 1:1 rate" do
    it "triggers alert when credits balance drops below threshold" do
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Credits Wallet",
        code: "credits-wallet",
        currency: "EUR",
        granted_credits: "100",
        invoice_requires_successful_payment: false
      }, as: :model)

      expect(wallet.credits_balance).to eq(100)
      expect(wallet.balance_cents).to eq(100_00)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_credits_balance,
        code: :low_credits,
        name: "Low Credits Alert",
        thresholds: [
          {value: 80, code: :notice},
          {value: 50, code: :warn}
        ]
      }, as: :model)

      expect(alert.alert_type).to eq("wallet_credits_balance")
      expect(alert.direction).to eq("decreasing")

      # First event - establishes baseline at 90 credits
      send_event!(subscription, 10)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.credits_balance).to eq(90)
      alert.reload
      expect(alert.previous_value).to eq(90)

      # Second event - balance goes from 90 to 70 credits, crosses 80 threshold
      send_event!(subscription, 20)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.credits_balance).to eq(70)

      expect(alert.triggered_alerts.count).to eq(1)
      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(70)
      expect(ta.crossed_thresholds).to eq([
        {"code" => "notice", "value" => "80.0", "recurring" => false}
      ])

      webhook = webhooks_sent.find { |w| w[:webhook_type] == "alert.triggered" }
      expect(webhook).to be_present
      expect(webhook[:triggered_alert]).to include({
        alert_type: "wallet_credits_balance",
        current_value: "70.0",
        alert_code: "low_credits"
      })
    end
  end

  describe "credits with different rate" do
    it "calculates correct credits based on rate" do
      # Rate of $2 = 1 credit, so 50 credits = $100
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "2",
        name: "Premium Credits Wallet",
        code: "premium-wallet",
        currency: "EUR",
        granted_credits: "50",
        invoice_requires_successful_payment: false
      }, as: :model)

      expect(wallet.credits_balance).to eq(50)
      expect(wallet.balance_cents).to eq(100_00)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_credits_balance,
        code: :credits_low,
        thresholds: [
          {value: 40, code: :notice},
          {value: 30, code: :warn}
        ]
      }, as: :model)

      # First event ($10 = 5 credits consumed) - establishes baseline at 45 credits
      send_event!(subscription, 10)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.credits_balance).to eq(45)
      alert.reload
      expect(alert.previous_value).to eq(45)

      # Second event ($30 = 15 credits consumed) - balance goes from 45 to 30 credits
      send_event!(subscription, 30)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(60_00)
      expect(wallet.credits_balance).to eq(30)

      expect(alert.triggered_alerts.count).to eq(1)
      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(30)
      expect(ta.crossed_thresholds.map { |t| t["code"] }).to contain_exactly("notice", "warn")
    end
  end

  describe "multiple thresholds with recurring" do
    it "triggers recurring threshold each time it is crossed" do
      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Recurring Credits Wallet",
        code: "recurring-wallet",
        currency: "EUR",
        granted_credits: "100",
        invoice_requires_successful_payment: false
      }, as: :model)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      # Initial threshold at 90 credits, then recurring every 10 credits below that
      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_credits_balance,
        code: :recurring_credits,
        thresholds: [
          {value: 90, code: :initial},
          {value: 10, code: :low, recurring: true}
        ]
      }, as: :model)

      # First event - establishes baseline at 95 credits
      send_event!(subscription, 5)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.credits_balance).to eq(95)
      alert.reload
      expect(alert.previous_value).to eq(95)

      # Second event - balance goes from 95 to 70 credits, crosses 90 one-time threshold
      send_event!(subscription, 25)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.credits_balance).to eq(70)
      expect(alert.triggered_alerts.count).to eq(1)
      expect(alert.triggered_alerts.sole.crossed_thresholds).to eq([
        {"code" => "initial", "value" => "90.0", "recurring" => false},
        {"code" => "low", "value" => "70.0", "recurring" => true},
        {"code" => "low", "value" => "80.0", "recurring" => true}
      ])

      # Third event - balance goes from 70 to 50 credits, crosses multiple recurring thresholds
      send_event!(subscription, 20)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.credits_balance).to eq(50)

      alert.reload
      expect(alert.triggered_alerts.count).to eq(2)
      ta2 = alert.triggered_alerts.order(:created_at).last
      # Recurring thresholds are crossed starting from the initial (90) going down by step (10)
      expect(ta2.crossed_thresholds).to eq([
        {"code" => "low", "value" => "50.0", "recurring" => true},
        {"code" => "low", "value" => "60.0", "recurring" => true},
        {"code" => "low", "value" => "70.0", "recurring" => true}
      ])
    end
  end
end
