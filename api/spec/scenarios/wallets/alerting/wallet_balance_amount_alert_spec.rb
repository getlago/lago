# frozen_string_literal: true

require "rails_helper"

describe "Wallet Balance Amount Alerts", :premium, transaction: false do
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

  def create_test_wallet(granted_credits: "100", rate_amount: "1")
    create_wallet({
      external_customer_id: customer.external_id,
      rate_amount:,
      name: "Test Wallet",
      code: "test-wallet",
      currency: "EUR",
      granted_credits:,
      invoice_requires_successful_payment: false
    }, as: :model)
  end

  before { charge }

  describe "basic threshold crossing (decreasing direction)" do
    it "triggers alert when wallet balance drops below threshold" do
      wallet = create_test_wallet(granted_credits: "100")
      expect(wallet.balance_cents).to eq(100_00)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :low_balance,
        name: "Low Balance Alert",
        thresholds: [
          {value: 80_00, code: :warn},
          {value: 50_00, code: :critical},
          {value: 20_00, code: :emergency}
        ]
      }, as: :model)

      expect(alert.alert_type).to eq("wallet_balance_amount")
      expect(alert.direction).to eq("decreasing")
      expect(alert.thresholds.count).to eq(3)

      # First event - establishes baseline (pay-in-advance invoice deducts from wallet)
      send_event!(subscription, 10)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(90_00)

      alert.reload
      expect(alert.previous_value).to eq(90_00)
      expect(alert.triggered_alerts.count).to eq(0)

      # Second event - crosses the $80 threshold (balance goes from $90 to $70)
      send_event!(subscription, 20)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(70_00)

      expect(alert.triggered_alerts.count).to eq(1)
      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(70_00)
      expect(ta.previous_value).to eq(90_00)
      expect(ta.crossed_thresholds).to eq([
        {"code" => "warn", "value" => "8000.0", "recurring" => false}
      ])

      webhook = webhooks_sent.find { |w| w[:webhook_type] == "alert.triggered" }
      expect(webhook).to be_present
      expect(webhook[:object_type]).to eq("triggered_alert")
      expect(webhook[:triggered_alert]).to include({
        lago_id: ta.id,
        alert_type: "wallet_balance_amount",
        current_value: "7000.0",
        previous_value: "9000.0",
        alert_code: "low_balance",
        alert_name: "Low Balance Alert"
      })
      expect(webhook[:triggered_alert][:crossed_thresholds]).to eq([
        {"code" => "warn", "value" => "8000.0", "recurring" => false}
      ])
    end
  end

  describe "multiple threshold crossing at once" do
    it "triggers alert with all crossed thresholds" do
      wallet = create_test_wallet(granted_credits: "100")

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :multi_threshold,
        thresholds: [
          {value: 90_00, code: :notice},
          {value: 70_00, code: :warn},
          {value: 50_00, code: :critical}
        ]
      }, as: :model)

      # First event - establishes baseline at $95
      send_event!(subscription, 5)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(95_00)
      alert.reload
      expect(alert.previous_value).to eq(95_00)

      # Second event - crosses all three thresholds at once (balance goes from $95 to $40)
      send_event!(subscription, 55)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(40_00)

      expect(alert.triggered_alerts.count).to eq(1)
      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(40_00)
      expect(ta.crossed_thresholds.map { |t| t["code"] }).to contain_exactly("notice", "warn", "critical")
    end
  end

  describe "no alert when threshold not crossed" do
    it "does not trigger alert when balance stays above threshold" do
      wallet = create_test_wallet(granted_credits: "100")

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :low_balance,
        thresholds: [{value: 50_00, code: :warn}]
      }, as: :model)

      # First event - establishes baseline at $90
      send_event!(subscription, 10)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(90_00)
      alert.reload
      expect(alert.previous_value).to eq(90_00)

      # Second event - balance goes from $90 to $80, still above $50 threshold
      send_event!(subscription, 10)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(80_00)

      expect(alert.triggered_alerts.count).to eq(0)
      expect(webhooks_sent.none? { |w| w[:webhook_type] == "alert.triggered" }).to be true
    end
  end

  describe "recurring threshold" do
    it "triggers alert each time recurring threshold is crossed" do
      wallet = create_test_wallet(granted_credits: "100")

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      # Initial threshold at $80, then recurring every $20 below that
      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :recurring_alert,
        thresholds: [
          {value: 80_00, code: :initial},
          {value: 20_00, code: :low, recurring: true}
        ]
      }, as: :model)

      # First event - establishes baseline at $95
      send_event!(subscription, 5)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(95_00)
      alert.reload
      expect(alert.previous_value).to eq(95_00)

      # Second event - balance goes from $95 to $70, crossing $80 one-time threshold
      send_event!(subscription, 25)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(70_00)

      expect(alert.triggered_alerts.count).to eq(1)
      ta1 = alert.triggered_alerts.first
      expect(ta1.crossed_thresholds).to eq([
        {"code" => "initial", "value" => "8000.0", "recurring" => false}
      ])

      # Third event - balance goes from $70 to $50, crossing $60 recurring threshold
      send_event!(subscription, 20)
      recalculate_wallet_balances

      wallet.reload
      expect(wallet.balance_cents).to eq(50_00)

      alert.reload
      expect(alert.triggered_alerts.count).to eq(2)
      ta2 = alert.triggered_alerts.order(:created_at).last
      expect(ta2.crossed_thresholds).to eq([
        {"code" => "low", "value" => "6000.0", "recurring" => true}
      ])
    end
  end

  describe "progressive usage consumption" do
    it "triggers alerts progressively as balance decreases" do
      wallet = create_test_wallet(granted_credits: "100")

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub-1",
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole

      alert = create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :progressive,
        thresholds: [
          {value: 70_00, code: :notice},
          {value: 40_00, code: :warn},
          {value: 10_00, code: :critical}
        ]
      }, as: :model)

      # First event - establishes baseline at $90
      send_event!(subscription, 10)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(90_00)
      alert.reload
      expect(alert.previous_value).to eq(90_00)

      # Second event - balance goes from $90 to $80, no thresholds crossed
      send_event!(subscription, 10)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(80_00)
      expect(alert.triggered_alerts.count).to eq(0)

      # Third event - balance goes from $80 to $60, crosses $70 threshold
      send_event!(subscription, 20)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(60_00)
      expect(alert.triggered_alerts.count).to eq(1)
      expect(alert.triggered_alerts.sole.crossed_thresholds.map { |t| t["code"] }).to eq(["notice"])

      # Fourth event - balance goes from $60 to $30, crosses $40 threshold
      send_event!(subscription, 30)
      recalculate_wallet_balances
      wallet.reload
      expect(wallet.balance_cents).to eq(30_00)
      expect(alert.triggered_alerts.count).to eq(2)
      expect(alert.triggered_alerts.order(:created_at).last.crossed_thresholds.map { |t| t["code"] }).to eq(["warn"])
    end
  end
end
