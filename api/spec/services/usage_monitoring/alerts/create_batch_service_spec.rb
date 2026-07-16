# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::Alerts::CreateBatchService do
  describe ".call" do
    subject(:result) { described_class.call(organization:, alertable:, alerts_params:) }

    let(:organization) { create(:organization) }
    let(:alertable) { create(:subscription, organization:) }
    let(:billable_metrics) { create_list(:billable_metric, 2, organization:) }
    let(:alerts_params) do
      [
        {
          alert_type: "billable_metric_current_usage_amount",
          code: "alert1",
          name: "First Alert",
          billable_metric_code: billable_metrics[0].code,
          thresholds: [{code: "warning", value: 80}]
        },
        {
          alert_type: "billable_metric_current_usage_amount",
          code: "alert2",
          name: "Second Alert",
          billable_metric_code: billable_metrics[1].code,
          thresholds: [{code: "critical", value: 100}]
        }
      ]
    end

    it "creates multiple alerts" do
      expect { result }.to change(UsageMonitoring::Alert, :count).by(2)
      expect(result).to be_success
      expect(result.alerts.map(&:code)).to match_array %w[alert1 alert2]
      expect(result.alerts.map(&:name)).to match_array ["First Alert", "Second Alert"]
    end

    context "when organization is nil" do
      subject(:result) { described_class.call(organization: nil, alertable:, alerts_params:) }

      it "returns a not found failure" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("organization_not_found")
      end
    end

    context "when alertable is nil" do
      let(:alertable) { nil }

      it "returns a not found failure" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("alertable_not_found")
      end
    end

    context "when alertable is a wallet" do
      let(:alertable) { create(:wallet, organization:) }

      let(:alerts_params) do
        [
          {
            alert_type: "wallet_balance_amount",
            code: "alert1",
            name: "First Alert",
            thresholds: [{code: "warning", value: 80}]
          },
          {
            alert_type: "wallet_credits_balance",
            code: "alert2",
            name: "Second Alert",
            thresholds: [{code: "critical", value: 100}]
          }
        ]
      end

      it "creates multiple alerts for the wallet" do
        expect { result }.to change(UsageMonitoring::Alert, :count).by(2)
        expect(result).to be_success
        expect(result.alerts).to match_array([
          have_attributes(code: "alert1", name: "First Alert", wallet: alertable),
          have_attributes(code: "alert2", name: "Second Alert", wallet: alertable)
        ])
      end
    end

    context "when alerts_params is empty" do
      let(:alerts_params) { [] }

      it "returns a validation failure" do
        expect(result).to be_failure
        expect(result.error.messages[:alerts]).to include("no_alerts")
      end
    end

    context "when alerts_params is nil" do
      let(:alerts_params) { nil }

      it "returns a validation failure" do
        expect(result).to be_failure
        expect(result.error.messages[:alerts]).to include("no_alerts")
      end
    end

    context "when one alert has invalid params" do
      let(:alerts_params) do
        [
          {
            alert_type: "current_usage_amount",
            code: "alert1",
            thresholds: [{value: 80}]
          },
          {
            alert_type: "invalid_type",
            code: "alert2",
            thresholds: [{value: 100}]
          }
        ]
      end

      it "rolls back all alerts and returns errors" do
        expect { result }.not_to change(UsageMonitoring::Alert, :count)
        expect(result).to be_failure
        expect(result.alerts).to be_empty
        expect(result.error.messages).to have_key(1)
        expect(result.error.messages[1][:params]).to eq(alerts_params[1])
        expect(result.error.messages[1][:errors]).to include("invalid_type")
      end
    end

    context "when alerts have duplicate codes" do
      let(:alerts_params) do
        [
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "same_code",
            billable_metric_code: billable_metrics[0].code,
            thresholds: [{value: 80}]
          },
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "same_code",
            billable_metric_code: billable_metrics[1].code,
            thresholds: [{value: 100}]
          }
        ]
      end

      it "rolls back all alerts and returns errors" do
        expect { result }.not_to change(UsageMonitoring::Alert, :count)
        expect(result).to be_failure
        expect(result.error.messages).to have_key(1)
        expect(result.error.messages[1][:params]).to eq(alerts_params[1])
        expect(result.error.messages[1][:errors]).to include("value_already_exist")
      end
    end

    context "when creating the same alert type for the same billable metric" do
      let(:alerts_params) do
        [
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "alert1",
            billable_metric_code: billable_metrics[0].code,
            thresholds: [{value: 80}]
          },
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "alert2",
            billable_metric_code: billable_metrics[0].code,
            thresholds: [{value: 100}]
          }
        ]
      end

      it "rolls back all alerts and returns errors" do
        expect { result }.not_to change(UsageMonitoring::Alert, :count)
        expect(result).to be_failure
        expect(result.error.messages).to have_key(1)
        expect(result.error.messages[1][:params]).to eq(alerts_params[1])
        expect(result.error.messages[1][:errors]).to include("alert_already_exists")
      end
    end

    context "when creating multiple differently invalid alerts" do
      let(:alerts_params) do
        [
          { # invalid type
            alert_type: "invalid_type",
            code: "alert1",
            thresholds: [{value: 80}]
          },
          { # missing thresholds
            alert_type: "billable_metric_current_usage_amount",
            code: "alert2",
            billable_metric_code: billable_metrics[0].code,
            thresholds: []
          },
          { # the only correct one
            alert_type: "billable_metric_current_usage_amount",
            code: "alert3",
            billable_metric_code: billable_metrics[1].code,
            thresholds: [{value: 100}]
          },
          { # duplicated alert type + billable metric
            alert_type: "billable_metric_current_usage_amount",
            code: "alert4",
            billable_metric_code: billable_metrics[1].code,
            thresholds: [{value: 100}]
          },
          { # duplicated code
            alert_type: "current_usage_amount",
            code: "alert3",
            thresholds: [{value: 100}]
          }
        ]
      end

      it "rolls back all alerts and returns all errors" do
        expect { result }.not_to change(UsageMonitoring::Alert, :count)
        expect(result).to be_failure
        expect(result.error.messages.size).to eq(4)
        expect(result.error.messages[0][:params]).to eq(alerts_params[0])
        expect(result.error.messages[0][:errors]).to include("invalid_type")
        expect(result.error.messages[1][:params]).to eq(alerts_params[1])
        expect(result.error.messages[1][:errors]).to include("value_is_mandatory")
        expect(result.error.messages[3][:params]).to eq(alerts_params[3])
        expect(result.error.messages[3][:errors]).to include("alert_already_exists")
        expect(result.error.messages[4][:params]).to eq(alerts_params[4])
        expect(result.error.messages[4][:errors]).to include("value_already_exist")
      end
    end

    context "when sending existing and non-existing billable metric codes" do
      let(:alerts_params) do
        [
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "alert0",
            billable_metric_code: "first_non_existing_code",
            thresholds: [{value: 50}]
          },
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "alert1",
            billable_metric_code: billable_metrics[0].code,
            thresholds: [{value: 80}]
          },
          {
            alert_type: "billable_metric_current_usage_amount",
            code: "alert2",
            billable_metric_code: "non_existing_code",
            thresholds: [{value: 100}]
          }
        ]
      end

      it "rolls back all alerts and returns all errors" do
        expect { result }.not_to change(UsageMonitoring::Alert, :count)
        expect(result).to be_failure
        expect(result.error.messages).to have_key(0)
        expect(result.error.messages).to have_key(2)
        expect(result.error.messages[0][:params]).to eq(alerts_params[0])
        expect(result.error.messages[0][:errors]).to eq("billable_metric_not_found")
        expect(result.error.messages[2][:params]).to eq(alerts_params[2])
        expect(result.error.messages[2][:errors]).to eq("billable_metric_not_found")
      end
    end
  end
end
