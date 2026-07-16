# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::FreeTrialSubscriptionsBillerJob do
  subject { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    before { allow(Subscriptions::FreeTrialBillingService).to receive(:call) }

    it "calls Subscriptions::FreeTrialBillingService" do
      described_class.perform_now

      expect(Subscriptions::FreeTrialBillingService).to have_received(:call)
    end
  end
end
