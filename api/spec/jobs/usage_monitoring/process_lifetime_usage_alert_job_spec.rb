# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessLifetimeUsageAlertJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }
  let(:alert) { create(:billable_metric_lifetime_usage_units_alert, organization:, subscription_external_id: subscription.external_id) }

  it_behaves_like "a unique job" do
    let(:job_args) { [{alert:, subscription:}] }
  end

  describe "#perform" do
    before do
      allow(UsageMonitoring::ProcessLifetimeUsageAlertService).to receive(:call!)
    end

    it "calls ProcessLifetimeUsageAlertService with the alert and subscription" do
      described_class.perform_now(alert:, subscription:)
      expect(UsageMonitoring::ProcessLifetimeUsageAlertService).to have_received(:call!).with(alert:, subscription:)
    end
  end
end
