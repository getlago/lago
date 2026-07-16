# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessWalletAlertsService do
  describe "#call" do
    subject(:result) { described_class.call(wallet:) }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:wallet) { create(:wallet, organization:, customer:, balance_cents: 400, ongoing_balance_cents: 400, credits_balance: 4.0, credits_ongoing_balance: 4.0) }

    context "when wallet has no alerts" do
      it "returns success without processing" do
        allow(UsageMonitoring::ProcessAlertService).to receive(:call)
        expect(result).to be_success
        expect(UsageMonitoring::ProcessAlertService).not_to have_received(:call)
      end
    end

    context "when wallet has alerts" do
      let(:alert) do
        create(
          :wallet_balance_amount_alert,
          wallet:,
          organization:,
          thresholds: [500, 800],
          previous_value: 1000,
          direction: "decreasing"
        )
      end

      before { alert }

      it "processes the alert and triggers when thresholds are crossed" do
        expect(result).to be_success

        triggered_alert = organization.triggered_alerts.sole
        expect(triggered_alert.alert).to eq(alert)
        expect(triggered_alert.wallet).to eq(wallet)
        expect(triggered_alert.subscription).to be_nil
        expect(triggered_alert.current_value).to eq(400)
        expect(triggered_alert.previous_value).to eq(1000)
        expect(triggered_alert.crossed_thresholds.map(&:symbolize_keys)).to contain_exactly(
          {code: "warn500", value: "500.0", recurring: false},
          {code: "warn800", value: "800.0", recurring: false}
        )

        expect(SendWebhookJob).to have_been_enqueued.once.with("alert.triggered", triggered_alert)
      end

      it "updates alert previous_value and last_processed_at" do
        result

        alert.reload
        expect(alert.previous_value).to eq(400)
        expect(alert.last_processed_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "when wallet has credits balance alert" do
      let!(:alert) do
        create(
          :wallet_credits_balance_alert,
          wallet:,
          organization:,
          thresholds: [5, 10],
          previous_value: 15,
          direction: "decreasing"
        )
      end

      it "processes the credits balance alert" do
        expect(result).to be_success

        triggered_alert = organization.triggered_alerts.sole
        expect(triggered_alert.alert).to eq(alert)
        expect(triggered_alert.current_value).to eq(4.0)
        expect(triggered_alert.crossed_thresholds.map(&:symbolize_keys)).to contain_exactly(
          {code: "warn5", value: "5.0", recurring: false},
          {code: "warn10", value: "10.0", recurring: false}
        )
      end
    end

    context "when wallet has ongoing_balance_amount alert" do
      let!(:alert) do
        create(
          :wallet_ongoing_balance_amount_alert,
          wallet:,
          organization:,
          thresholds: [500, 800],
          previous_value: 1000,
          direction: "decreasing"
        )
      end

      it "processes the ongoing balance alert" do
        expect(result).to be_success

        triggered_alert = organization.triggered_alerts.sole
        expect(triggered_alert.alert).to eq(alert)
        expect(triggered_alert.current_value).to eq(400)
        expect(triggered_alert.previous_value).to eq(1000)
        expect(triggered_alert.crossed_thresholds.map(&:symbolize_keys)).to contain_exactly(
          {code: "warn500", value: "500.0", recurring: false},
          {code: "warn800", value: "800.0", recurring: false}
        )
      end
    end

    context "when wallet has credits_ongoing_balance alert" do
      let!(:alert) do
        create(
          :wallet_credits_ongoing_balance_alert,
          wallet:,
          organization:,
          thresholds: [5, 10],
          previous_value: 15,
          direction: "decreasing"
        )
      end

      it "processes the credits balance alert" do
        expect(result).to be_success

        triggered_alert = organization.triggered_alerts.sole
        expect(triggered_alert.alert).to eq(alert)
        expect(triggered_alert.current_value).to eq(4.0)
        expect(triggered_alert.previous_value).to eq(15.0)
        expect(triggered_alert.crossed_thresholds.map(&:symbolize_keys)).to contain_exactly(
          {code: "warn5", value: "5.0", recurring: false},
          {code: "warn10", value: "10.0", recurring: false}
        )
      end
    end

    context "when no thresholds are crossed" do
      let!(:alert) do
        create(
          :wallet_balance_amount_alert,
          wallet:,
          organization:,
          thresholds: [100, 200],
          previous_value: 500,
          direction: "decreasing"
        )
      end

      it "does not trigger the alert" do
        expect(result).to be_success
        expect(organization.triggered_alerts.count).to eq(0)
        expect(SendWebhookJob).not_to have_been_enqueued
      end

      it "updates alert previous_value" do
        result

        alert.reload
        expect(alert.previous_value).to eq(400)
        expect(alert.last_processed_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "when alert direction is increasing" do
      let(:alert) do
        create(
          :wallet_balance_amount_alert,
          wallet:,
          organization:,
          thresholds: [300, 500],
          previous_value: 200,
          direction: "increasing"
        )
      end

      before { alert }

      it "triggers when value increases past thresholds" do
        expect(result).to be_success

        triggered_alert = organization.triggered_alerts.sole
        expect(triggered_alert.crossed_thresholds.map(&:symbolize_keys)).to contain_exactly(
          {code: "warn300", value: "300.0", recurring: false}
        )
      end
    end
  end
end
