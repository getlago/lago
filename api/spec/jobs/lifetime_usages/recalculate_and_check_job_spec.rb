# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::RecalculateAndCheckJob do
  let(:organization) { create(:organization, :premium, premium_integrations:) }
  let(:lifetime_usage) { create(:lifetime_usage, organization:) }

  let(:premium_integrations) { ["progressive_billing"] }

  it_behaves_like "a configurable queue", "billing_low_priority", "SIDEKIQ_BILLING" do
    let(:arguments) { lifetime_usage }
  end

  it "delegates to the Calculate service" do
    allow(LifetimeUsages::CalculateService).to receive(:call!)
    allow(LifetimeUsages::CheckThresholdsService).to receive(:call!)
    described_class.perform_now(lifetime_usage)
    expect(LifetimeUsages::CalculateService).to have_received(:call!).with(lifetime_usage:, current_usage: nil)
    expect(LifetimeUsages::CheckThresholdsService).not_to have_received(:call!)
  end

  context "when premium", :premium do
    it "delegates to the RecalculateAndCheck service" do
      allow(LifetimeUsages::CalculateService).to receive(:call!)
      allow(LifetimeUsages::CheckThresholdsService).to receive(:call!)
      described_class.perform_now(lifetime_usage)
      expect(LifetimeUsages::CalculateService).to have_received(:call!).with(lifetime_usage:, current_usage: nil)
      expect(LifetimeUsages::CheckThresholdsService).to have_received(:call!).with(lifetime_usage:)
    end

    context "when progressive billing is disabled" do
      let(:premium_integrations) { [] }

      it "delegates to the RecalculateAndCheck service" do
        allow(LifetimeUsages::CalculateService).to receive(:call!)
        allow(LifetimeUsages::CheckThresholdsService).to receive(:call!)
        described_class.perform_now(lifetime_usage)
        expect(LifetimeUsages::CalculateService).to have_received(:call!).with(lifetime_usage:, current_usage: nil)
        expect(LifetimeUsages::CheckThresholdsService).not_to have_received(:call!)
      end
    end
  end

  describe "retry_on" do
    [
      [Customers::FailedToAcquireLock.new("customer-1-prepaid_credit"), 25],
      [ActiveRecord::StaleObjectError.new("Attempted to update a stale object: Wallet."), 25]
    ].each do |error, attempts|
      error_class = error.class

      context "when a #{error_class} error is raised" do
        before do
          allow(LifetimeUsages::CalculateService).to receive(:call).and_raise(error)
        end

        it "raises a #{error_class.name} error and retries" do
          assert_performed_jobs(attempts, only: [described_class]) do
            expect do
              described_class.perform_later(lifetime_usage)
            end.to raise_error(error_class)
          end
        end
      end
    end
  end
end
