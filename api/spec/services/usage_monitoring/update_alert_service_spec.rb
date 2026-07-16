# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::UpdateAlertService do
  subject(:result) { described_class.call(alert:, params:) }

  let(:organization) { create(:organization, premium_integrations:) }
  let(:premium_integrations) { [] }
  let(:alert) { create(:alert, thresholds: [1, 50], organization: organization) }

  describe "#call" do
    let(:params) do
      {code: "new_code", name: "Renamed", thresholds: [
        {value: 40},
        {code: :warn, value: 100},
        {code: :critical, value: 200, recurring: true}
      ]}
    end

    it "updates the alert" do
      expect(result).to be_success
      expect(result.alert).to eq(alert)
      expect(alert.reload.name).to eq("Renamed")
      expect(alert.reload.code).to eq("new_code")
      expect(alert.reload.thresholds.map(&:value)).to eq [40, 100, 200]
      expect(alert.reload.thresholds.map(&:code)).to eq [nil, "warn", "critical"]
    end

    context "with a billable_metric_id" do
      let(:alert) { create(:billable_metric_current_usage_amount_alert, thresholds: [50]) }
      let(:billable_metric) { create(:billable_metric, organization: alert.organization) }
      let(:params) do
        {code: "new_code", name: "Renamed", billable_metric_id: billable_metric.id, thresholds: [
          {value: 40},
          {code: :warn, value: 100},
          {code: :critical, value: 200, recurring: true}
        ]}
      end

      it "updates the alert" do
        expect(result).to be_success
        expect(result.alert.billable_metric_id).to eq(billable_metric.id)
      end

      context "when alert is not billable_metric_current_usage_amount" do
        let(:alert) { create(:usage_current_amount_alert, thresholds: [50]) }

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:billable_metric]).to eq ["value_must_be_blank"]
        end
      end

      context "when billable_metric is not found" do
        let(:params) { {code: "new_code", billable_metric_id: "not-found"} }

        it "returns a record validation failure result" do
          expect(result).to be_failure
          expect(result.error.message).to eq "billable_metric_not_found"
        end
      end

      context "when code already exists" do
        it "returns a record validation failure result" do
          create(:billable_metric_current_usage_amount_alert, organization: alert.organization, code: "new_code", subscription_external_id: alert.subscription_external_id)
          expect(result).to be_failure
          expect(result.error.messages[:code]).to eq(["value_already_exist"])
        end
      end
    end

    context "with too many thresholds" do
      let(:params) do
        {
          thresholds: Array.new(21) do |i|
            {code: "warning#{i}", value: 10 + i}
          end
        }
      end

      it "returns a record validation failure result" do
        expect(result).to be_failure
        expect(result.error.message).to include("too_many_thresholds")
      end
    end

    context "when thresholds have duplicate values" do
      let(:params) { {thresholds: [{value: 1}, {value: 1}]} }

      it "returns a validation failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:thresholds]).to include("duplicate_threshold_values")
      end
    end

    context "when thresholds have duplicate values with falsy recurring variants" do
      [
        [{value: 1, recurring: false}, {value: 1, recurring: "0"}],
        [{value: 1, recurring: false}, {value: 1, recurring: 0}],
        [{value: 1, recurring: "false"}, {value: 1, recurring: false}],
        [{value: 1, recurring: "0"}, {value: 1, recurring: 0}],
        [{value: 1}, {value: 1, recurring: false}]
      ].each do |thresholds_pair|
        context "with recurring values #{thresholds_pair.map { |t| t[:recurring].inspect }.join(" and ")}" do
          let(:params) { {thresholds: thresholds_pair} }

          it "returns a validation failure result" do
            expect(result).to be_failure
            expect(result.error.messages[:thresholds]).to include("duplicate_threshold_values")
          end
        end
      end
    end

    context "when thresholds have same value but different recurring flags" do
      let(:params) { {thresholds: [{value: 100}, {value: 100, recurring: true}]} }

      it "updates the alert" do
        expect(result).to be_success
        expect(alert.reload.thresholds.pluck(:value, :recurring)).to contain_exactly(
          [100, false], [100, true]
        )
      end
    end

    context "when a threshold value is nil" do
      let(:params) { {thresholds: [{value: nil}]} }

      it "returns a validation failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:"thresholds:value"]).to include("value_is_mandatory")
      end
    end

    context "when a threshold value is not a valid number" do
      let(:params) { {thresholds: [{value: "abc"}]} }

      it "returns a validation failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:"thresholds:value"]).to include("value_is_invalid")
      end
    end

    context "when threshold values are valid numeric strings" do
      let(:params) { {thresholds: [{value: "100"}, {value: "200.5"}]} }

      it "updates the alert" do
        expect(result).to be_success
        expect(alert.reload.thresholds.map(&:value)).to eq [100, 200.5]
      end
    end

    context "when one-time threshold values are negative" do
      let(:params) { {thresholds: [{value: "100"}, {value: "-100"}]} }

      it "creates the alert" do
        expect(result).to be_success
        expect(result.alert).to be_persisted
      end
    end

    context "when recurring threshold values are negative" do
      let(:params) do
        {
          thresholds: [
            {value: "100", recurring: "true"},
            {value: "-100", recurring: "true"}
          ]
        }
      end

      it "returns a record validation failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:"thresholds:value"]).to eq(["recurring_value_is_negative"])
      end
    end

    context "with direction param" do
      let(:alert) { create(:alert, thresholds: [1, 50], organization: organization, direction: "increasing") }
      let(:params) { {direction: "decreasing"} }

      it "ignores direction param and does not modify it" do
        expect(result).to be_success
        expect(alert.reload.direction).to eq("increasing")
      end
    end

    context "when tracking subscription activity", :premium do
      it "creates a subscription activity record" do
        expect { result }.to change(UsageMonitoring::SubscriptionActivity, :count).by(1)

        activity = UsageMonitoring::SubscriptionActivity.last
        expect(activity.organization_id).to eq(organization.id)
      end

      context "when no active subscription matches" do
        before do
          alert
          organization.subscriptions.update_all(status: :terminated) # rubocop:disable Rails/SkipsModelValidations
        end

        it "does not create a subscription activity" do
          expect { result }.not_to change(UsageMonitoring::SubscriptionActivity, :count)
        end
      end

      context "when license is not premium" do
        it "does not create a subscription activity" do
          allow(License).to receive(:premium?).and_return(false)
          expect { result }.not_to change(UsageMonitoring::SubscriptionActivity, :count)
        end
      end
    end

    context "when updating a wallet alert" do
      let(:alert) { create(:wallet_balance_amount_alert, thresholds: [50], organization:) }
      let(:params) { {name: "Updated Wallet Alert"} }

      it "does not create a subscription activity" do
        expect { result }.not_to change(UsageMonitoring::SubscriptionActivity, :count)
      end

      context "when processing wallet alerts", :premium do
        it "enqueues ProcessWalletAlertsJob" do
          expect { result }.to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob).with(alert.wallet)
        end

        context "when license is not premium" do
          it "does not enqueue ProcessWalletAlertsJob" do
            allow(License).to receive(:premium?).and_return(false)
            expect { result }.not_to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob)
          end
        end
      end

      context "when wallet is terminated" do
        before do
          alert.wallet.mark_as_terminated!
        end

        it "does not enqueue ProcessWalletAlertsJob" do
          expect { result }.not_to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob)
        end
      end
    end
  end
end
