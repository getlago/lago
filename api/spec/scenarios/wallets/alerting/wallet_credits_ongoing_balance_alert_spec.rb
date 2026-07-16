# frozen_string_literal: true

require "rails_helper"

describe "Wallet Credits Ongoing Balance Alerts", :premium, transaction: false do
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
      alert_type: :wallet_credits_ongoing_balance,
      code: :ongoing_balance_alert,
      name: "Credits Ongoing Balance Alert",
      thresholds: [
        {value: 75, code: :warn},
        {value: 50, code: :critical},
        {value: 25, code: :emergency}
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
        alert_type: "wallet_credits_ongoing_balance",
        alert_code: "ongoing_balance_alert",
        alert_name: "Credits Ongoing Balance Alert",
        current_value: params[:current_value].to_f.to_s,
        previous_value: params[:previous_value].to_f.to_s,
        crossed_thresholds: params[:crossed_thresholds]
      })
    )
  end

  before { charge }

  describe "basic functionality" do
    it "triggers alert when credits ongoing balance goes down" do
      wallet = create_test_wallet(granted_credits: "100")
      expect(wallet.credits_ongoing_balance).to eq(100)

      subscription = create_test_subscription
      alert = create_test_wallet_alert(
        wallet,
        thresholds: [{value: 50, code: :alert, recurring: false}]
      )

      expect(alert).to have_attributes(
        alert_type: "wallet_credits_ongoing_balance",
        direction: "decreasing",
        thresholds: match_array([
          have_attributes({value: 50, code: "alert", recurring: false})
        ])
      )

      # First event - no alerts
      send_event!(subscription, 25)
      recalculate_wallet_balances

      expect(wallet.reload.credits_ongoing_balance).to eq(75)
      expect(alert.reload.previous_value).to eq(75)
      expect(alert.triggered_alerts.count).to eq(0)

      # Second event - one-time alert
      send_event!(subscription, 30)
      recalculate_wallet_balances

      expect(wallet.reload.credits_ongoing_balance).to eq(45)
      expect(alert.reload.previous_value).to eq(45)

      expect_alert_to_be_triggered(
        alert,
        current_value: 45,
        previous_value: 75,
        crossed_thresholds: [{"code" => "alert", "value" => "50.0", "recurring" => false}]
      )

      # Third event - no alert
      send_event!(subscription, 20)
      recalculate_wallet_balances

      expect(wallet.reload.credits_ongoing_balance).to eq(25)
      expect(alert.reload.previous_value).to eq(25)
      expect(alert.triggered_alerts.count).to eq(1)
    end

    context "when there were credits ongoing balance changes before first alert" do
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

        expect(wallet.reload.credits_ongoing_balance).to eq(70)
        expect(alert.reload.previous_value).to eq(70)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70,
          previous_value: 100,
          crossed_thresholds: [{"code" => "warn", "value" => "75.0", "recurring" => false}]
        )
      end
    end

    context "when no credits ongoing balance changes happened before first alert" do
      it "triggers alerts correctly" do
        wallet = create_test_wallet(granted_credits: "100")
        subscription = create_test_subscription
        alert = create_test_wallet_alert(wallet)

        # Send event - first alert
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(70)
        expect(alert.reload.previous_value).to eq(70)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70,
          previous_value: 100,
          crossed_thresholds: [{"code" => "warn", "value" => "75.0", "recurring" => false}]
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

        expect(wallet.reload.credits_ongoing_balance).to eq(70)
        expect(alert.reload.previous_value).to eq(70)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70,
          previous_value: 100,
          crossed_thresholds: [{"code" => "warn", "value" => "75.0", "recurring" => false}]
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

        expect(wallet.reload.credits_ongoing_balance).to eq(30)
        expect(alert.reload.previous_value).to eq(30)

        expect_alert_to_be_triggered(
          alert,
          current_value: 30,
          previous_value: 100,
          crossed_thresholds: [
            {"code" => "warn", "value" => "75.0", "recurring" => false},
            {"code" => "critical", "value" => "50.0", "recurring" => false}
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

        expect(wallet.reload.credits_ongoing_balance).to eq(70)
        expect(alert.reload.previous_value).to eq(70)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70,
          previous_value: 100,
          crossed_thresholds: [
            {"code" => "warn", "value" => "75.0", "recurring" => false}
          ]
        )

        # Second threshold
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(40)
        expect(alert.reload.previous_value).to eq(40)

        expect_alert_to_be_triggered(
          alert,
          current_value: 40,
          previous_value: 70,
          crossed_thresholds: [
            {"code" => "critical", "value" => "50.0", "recurring" => false}
          ]
        )

        # Third threshold
        send_event!(subscription, 30)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(10)
        expect(alert.reload.previous_value).to eq(10)

        expect_alert_to_be_triggered(
          alert,
          current_value: 10,
          previous_value: 40,
          crossed_thresholds: [
            {"code" => "emergency", "value" => "25.0", "recurring" => false}
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

        expect(wallet.reload.credits_ongoing_balance).to eq(90)
        expect(alert.reload.previous_value).to eq(90)

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

        expect(wallet.reload.credits_ongoing_balance).to eq(70)
        expect(alert.reload.previous_value).to eq(70)

        expect_alert_to_be_triggered(
          alert,
          current_value: 70,
          previous_value: 100,
          crossed_thresholds: [{"code" => "warn", "value" => "75.0", "recurring" => false}]
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
            {value: 80, code: :one_time, recurring: false},
            {value: 10, code: :recurring, recurring: true}
          ]
        )

        # First event - one-time alert
        send_event!(subscription, 25)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(75)
        expect(alert.reload.previous_value).to eq(75)

        expect_alert_to_be_triggered(
          alert,
          current_value: 75,
          previous_value: 100,
          crossed_thresholds: [{"code" => "one_time", "value" => "80.0", "recurring" => false}]
        )

        # Second event - recurring alert
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(65)
        expect(alert.reload.previous_value).to eq(65)

        expect_alert_to_be_triggered(
          alert,
          current_value: 65,
          previous_value: 75,
          crossed_thresholds: [{"code" => "recurring", "value" => "70.0", "recurring" => true}]
        )

        # Third event - recurring alert
        send_event!(subscription, 20)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(45)
        expect(alert.reload.previous_value).to eq(45)

        expect_alert_to_be_triggered(
          alert,
          current_value: 45,
          previous_value: 65,
          crossed_thresholds: [
            {"code" => "recurring", "value" => "50.0", "recurring" => true},
            {"code" => "recurring", "value" => "60.0", "recurring" => true}
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
            {value: 50, code: :positive, recurring: false},
            {value: -50, code: :negative, recurring: false}
          ]
        )

        # First event - positive alert, credits ongoing balance goes down to 40
        send_event!(subscription, 55)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(45)
        expect(alert.reload.previous_value).to eq(45)

        expect_alert_to_be_triggered(
          alert,
          current_value: 45,
          previous_value: 100,
          crossed_thresholds: [{"code" => "positive", "value" => "50.0", "recurring" => false}]
        )

        # Second event - negative alert, credits ongoing balance goes down to -60
        send_event!(subscription, 100)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(-55)
        expect(alert.reload.previous_value).to eq(-55)

        expect_alert_to_be_triggered(
          alert,
          current_value: -55,
          previous_value: 45,
          crossed_thresholds: [{"code" => "negative", "value" => "-50.0", "recurring" => false}]
        )
      end
    end

    context "when credits ongoing balance goes negative with a recurring threshold" do
      it "triggers recurring alerts when credits ongoing balance goes below 0" do
        wallet = create_test_wallet(granted_credits: "20")
        subscription = create_test_subscription

        alert = create_test_wallet_alert(
          wallet,
          thresholds: [
            {value: 15, code: :one_time, recurring: false},
            {value: 10, code: :recurring, recurring: true}
          ]
        )

        # First event - one-time alert
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(10)
        expect(alert.reload.previous_value).to eq(10)

        expect_alert_to_be_triggered(
          alert,
          current_value: 10,
          previous_value: 20,
          crossed_thresholds: [{"code" => "one_time", "value" => "15.0", "recurring" => false}]
        )

        # Second event - positive recurring alert at $5
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(0)
        expect(alert.reload.previous_value).to eq(0)

        expect_alert_to_be_triggered(
          alert,
          current_value: 0,
          previous_value: 10,
          crossed_thresholds: [{"code" => "recurring", "value" => "5.0", "recurring" => true}]
        )

        # Third event - negative recurring alert at -$5
        send_event!(subscription, 10)
        recalculate_wallet_balances

        expect(wallet.reload.credits_ongoing_balance).to eq(-10)
        expect(alert.reload.previous_value).to eq(-10)

        expect_alert_to_be_triggered(
          alert,
          current_value: -10,
          previous_value: 0,
          crossed_thresholds: [{"code" => "recurring", "value" => "-5.0", "recurring" => true}]
        )
      end
    end
  end
end
