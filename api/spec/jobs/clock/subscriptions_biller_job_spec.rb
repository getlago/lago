# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::SubscriptionsBillerJob do
  subject { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    let(:organization1) { create(:organization, api_keys: []) }
    let(:organization2) { create(:organization, api_keys: []) }

    before do
      organization1
      organization2
    end

    it "enqueues Subscriptions::OrganizationBillingJob for each organization" do
      expect do
        described_class.perform_now
      end.to have_enqueued_job(Subscriptions::OrganizationBillingJob).exactly(2).times
    end
  end
end
