# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::Alerts::DestroyAllService do
  describe ".call" do
    subject(:result) { described_class.call(alertable: alertable) }

    let(:organization) { create(:organization) }
    let(:alertable) { create(:subscription, organization:) }

    context "when alertable is a subscription" do
      let!(:alert1) do
        create(:usage_current_amount_alert, code: "a1", organization:,
          subscription_external_id: alertable.external_id, thresholds: [1, 2])
      end
      let!(:alert2) do
        create(:lifetime_usage_amount_alert, code: "a2", organization:,
          subscription_external_id: alertable.external_id, thresholds: [3])
      end
      let!(:other_alert) { create(:alert, organization:, thresholds: [4]) }

      it "discards all alerts for the subscription" do
        expect(result).to be_success

        expect(alert1.reload).to be_discarded
        expect(alert2.reload).to be_discarded
        expect(other_alert.reload).not_to be_discarded
      end

      it "deletes all thresholds for the discarded alerts" do
        expect { result }.to change(UsageMonitoring::AlertThreshold, :count).by(-3)
      end
    end

    context "when alertable is a wallet" do
      let(:alertable) { create(:wallet, organization:) }

      let!(:alert1) do
        create(:wallet_balance_amount_alert, code: "a1", organization:, wallet: alertable, thresholds: [1, 2])
      end
      let!(:alert2) do
        create(:wallet_credits_balance_alert, code: "a2", organization:, wallet: alertable, thresholds: [3])
      end
      let!(:other_alert) { create(:alert, organization:, thresholds: [4]) }

      it "discards all alerts for the wallet" do
        expect(result).to be_success

        expect(alert1.reload).to be_discarded
        expect(alert2.reload).to be_discarded
        expect(other_alert.reload).not_to be_discarded
      end

      it "deletes all thresholds for the discarded alerts" do
        expect { result }.to change(UsageMonitoring::AlertThreshold, :count).by(-3)
      end
    end

    context "when alertable is nil" do
      let(:alertable) { nil }
      let(:alert1) { nil }
      let(:alert2) { nil }

      it "returns a not found failure" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("alertable_not_found")
      end
    end

    context "when there are no alerts for the alertable" do
      it "returns success with empty alerts" do
        expect(result).to be_success
      end
    end
  end
end
