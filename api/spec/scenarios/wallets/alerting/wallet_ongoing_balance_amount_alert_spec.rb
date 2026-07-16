# frozen_string_literal: true

require "rails_helper"

describe "Wallet Ongoing Balance Amount Alerts", :premium, transaction: false do
  include_context "with webhook tracking"

  let(:organization) { create(:organization, webhook_url: "https://example.com") }
  let(:customer) { create(:customer, organization:, invoice_grace_period: 5) }

  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "amount") }
  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "1"}) }

  def send_event!(subscription, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric.field_name => amount}
    })
    perform_usage_update
  end

  def create_test_wallet(**params)
    create_wallet({
      external_customer_id: customer.external_id,
      rate_amount: "1",
      granted_credits: "100",
      name: "Test Wallet",
      code: "test-wallet",
      currency: "EUR",
      invoice_requires_successful_payment: false,
      **params
    }, as: :model)
  end

  def create_test_subscription(**params)
    create_subscription({
      external_customer_id: customer.external_id,
      external_id: "sub-1",
      plan_code: plan.code,
      **params
    })

    customer.subscriptions.sole
  end

  def create_test_wallet_alert(wallet, **params)
    create_wallet_alert(customer.external_id, wallet.code, {
      alert_type: :wallet_ongoing_balance_amount,
      code: :ongoing_balance_alert,
      name: "Ongoing Balance Alert",
      thresholds: [
        {value: 75_00, code: :warn},
        {value: 50_00, code: :critical},
        {value: 25_00, code: :emergency}
      ],
      **params
    }, as: :model)
  end

  def alert_webhooks
    webhooks_sent.select { it[:webhook_type] == "alert.triggered" }
  end

  def expect_alert_to_be_triggered(alert, **params)
    triggered = alert.triggered_alerts.order(:created_at).last
    expect(triggered).to have_attributes(params)

    webhook = alert_webhooks.last
    expect(webhook).to include(
      object_type: "triggered_alert",
      triggered_alert: include({
        lago_id: triggered.id,
        alert_type: "wallet_ongoing_balance_amount",
        alert_code: "ongoing_balance_alert",
        alert_name: "Ongoing Balance Alert",
        current_value: params[:current_value].to_f.to_s,
        previous_value: params[:previous_value].to_f.to_s,
        crossed_thresholds: params[:crossed_thresholds]
      })
    )
  end

  before { charge }

  describe "basic functionality" do
    it "triggers alert when ongoing balance goes down" do
      wallet = create_test_wallet(granted_credits: "100")
      expect(wallet.ongoing_balance_cents).to eq(100_00)

      subscription = create_test_subscription
      alert = create_test_wallet_alert(
        wallet,
        thresholds: [{value: 50_00, code: :alert, recurring: false}]
      )

      expect(alert).to have_attributes(
        alert_type: "wallet_ongoing_balance_amount",
        direction: "decreasing",
        thresholds: match_array([
          have_attributes({value: 50_00, code: "alert", recurring: false})
        ])
      )

      # First event - no alerts
      send_event!(subscription, 25)
      recalculate_wallet_balances

      expect(wallet.reload.ongoing_balance_cents).to eq(75_00)
      expect(alert.reload.previous_value).to eq(75_00)
      expect(alert.triggered_alerts.count).to eq(0)

      # Second event - one-time alert
      send_event!(subscription, 30)
      recalculate_wallet_balances

      expect(wallet.reload.ongoing_balance_cents).to eq(45_00)
      expect(alert.reload.previous_value).to eq(45_00)

      expect_alert_to_be_triggered(
        alert,
        current_value: 45_00,
        previous_value: 75_00,
        crossed_thresholds: [{"code" => "alert", "value" => "5000.0", "recurring" => false}]
      )

      # Third event - no alert
      send_event!(subscription, 20)
      recalculate_wallet_balances

      expect(wallet.reload.ongoing_balance_cents).to eq(25_00)
      expect(alert.reload.previous_value).to eq(25_00)
      expect(alert.triggered_alerts.count).to eq(1)
    end

    context "when there were ongoing balance changes before first alert" do
      it "triggers alerts correctly" do
        wallet = create_test_wallet(granted_credits: "50")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        # Top up wallet
        create_wallet_transaction({
          wallet_id: wallet.id,
          granted_credits: "50",
          name: "Top-up"
        }, as: :model)

        # Send event - first alert
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(70_00)
        expect(alert.reload.previous_value).to eq(70_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "warn", "value" => "7500.0", "recurring" => false}]
        )
      end
    end

    context "when no ongoing balance changes happened before first alert" do
      it "triggers alerts correctly" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        # Send event - first alert
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(70_00)
        expect(alert.reload.previous_value).to eq(70_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "warn", "value" => "7500.0", "recurring" => false}]
        )
      end
    end
  end

  describe "thresholds crossing" do
    context "when one threshold is crossed" do
      it "triggers the alert" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(70_00)
        expect(alert.reload.previous_value).to eq(70_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "warn", "value" => "7500.0", "recurring" => false}]
        )
      end
    end

    context "when multiple thresholds are crossed at once" do
      it "triggers one alert with multiple crossed_thersholds" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        send_event!(subscription, 70)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(30_00)
        expect(alert.reload.previous_value).to eq(30_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 30_00,
          previous_value: 100_00,
          crossed_thresholds: [
            {"code" => "warn", "value" => "7500.0", "recurring" => false},
            {"code" => "critical", "value" => "5000.0", "recurring" => false}
          ]
        )
      end
    end

    context "when multiple thresholds are crossed over time" do
      it "triggers alert multiple times" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        # First threshold
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(70_00)
        expect(alert.reload.previous_value).to eq(70_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70_00,
          previous_value: 100_00,
          crossed_thresholds: [
            {"code" => "warn", "value" => "7500.0", "recurring" => false}
          ]
        )

        # Second threshold
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(40_00)
        expect(alert.reload.previous_value).to eq(40_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 40_00,
          previous_value: 70_00,
          crossed_thresholds: [
            {"code" => "critical", "value" => "5000.0", "recurring" => false}
          ]
        )

        # Third threshold
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(10_00)
        expect(alert.reload.previous_value).to eq(10_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 10_00,
          previous_value: 40_00,
          crossed_thresholds: [
            {"code" => "emergency", "value" => "2500.0", "recurring" => false}
          ]
        )
      end
    end

    context "when no thresholds are crossed" do
      it "triggers one alert with multiple crossed_thersholds" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(90_00)
        expect(alert.reload.previous_value).to eq(90_00)

        expect(alert.triggered_alerts.count).to eq(0)
        expect(alert_webhooks).to be_empty
      end
    end
  end

  describe "thresholds types" do
    context "when only one-time thresholds are defined" do
      it "triggers the one-time alert" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(70_00)
        expect(alert.reload.previous_value).to eq(70_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "warn", "value" => "7500.0", "recurring" => false}]
        )
      end
    end

    context "when a recurring threshold is defined" do
      it "triggers the one-time and recurring alerts" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription

        alert = create_test_wallet_alert(
          wallet,
          thresholds: [
            {value: 80_00, code: :one_time, recurring: false},
            {value: 10_00, code: :recurring, recurring: true}
          ]
        )

        # First event - one-time alert
        send_event!(subscription, 25)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(75_00)
        expect(alert.reload.previous_value).to eq(75_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 75_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "one_time", "value" => "8000.0", "recurring" => false}]
        )

        # Second event - recurring alert
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(65_00)
        expect(alert.reload.previous_value).to eq(65_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 65_00,
          previous_value: 75_00,
          crossed_thresholds: [{"code" => "recurring", "value" => "7000.0", "recurring" => true}]
        )

        # Third event - recurring alert
        send_event!(subscription, 20)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(45_00)
        expect(alert.reload.previous_value).to eq(45_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 45_00,
          previous_value: 65_00,
          crossed_thresholds: [
            {"code" => "recurring", "value" => "5000.0", "recurring" => true},
            {"code" => "recurring", "value" => "6000.0", "recurring" => true}
          ]
        )
      end
    end

    context "when negative thresholds are defined" do
      it "triggers positive and negative alerts" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription

        alert = create_test_wallet_alert(
          wallet,
          thresholds: [
            {value: 50_00, code: :positive, recurring: false},
            {value: -50_00, code: :negative, recurring: false}
          ]
        )

        # First event - positive alert, ongoing balance goes down to $40
        send_event!(subscription, 55)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(45_00)
        expect(alert.reload.previous_value).to eq(45_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 45_00,
          previous_value: 100_00,
          crossed_thresholds: [{"code" => "positive", "value" => "5000.0", "recurring" => false}]
        )

        # Second event - negative alert, ongoing balance goes down to -$60
        send_event!(subscription, 100)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(-55_00)
        expect(alert.reload.previous_value).to eq(-55_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: -55_00,
          previous_value: 45_00,
          crossed_thresholds: [{"code" => "negative", "value" => "-5000.0", "recurring" => false}]
        )
      end
    end

    context "when ongoing balance goes negative with a recurring threshold" do
      it "triggers recurring alerts when ongoing balance goes below 0" do
        wallet = create_test_wallet(granted_credits: "20")
        subscription = create_test_subscription

        alert = create_test_wallet_alert(
          wallet,
          thresholds: [
            {value: 15_00, code: :one_time, recurring: false},
            {value: 10_00, code: :recurring, recurring: true}
          ]
        )

        # First event - one-time alert
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(10_00)
        expect(alert.reload.previous_value).to eq(10_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: 10_00,
          previous_value: 20_00,
          crossed_thresholds: [{"code" => "one_time", "value" => "1500.0", "recurring" => false}]
        )

        # Second event - positive recurring alert at $5
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(0)
        expect(alert.reload.previous_value).to eq(0)

        expect_alert_to_be_triggered(
          alert,
          current_value: 0,
          previous_value: 10_00,
          crossed_thresholds: [{"code" => "recurring", "value" => "500.0", "recurring" => true}]
        )

        # Third event - negative recurring alert at -$5
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.ongoing_balance_cents).to eq(-10_00)
        expect(alert.reload.previous_value).to eq(-10_00)

        expect_alert_to_be_triggered(
          alert,
          current_value: -10_00,
          previous_value: 0,
          crossed_thresholds: [{"code" => "recurring", "value" => "-500.0", "recurring" => true}]
        )
      end
    end
  end
end
