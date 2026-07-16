# frozen_string_literal: true

require "rails_helper"

describe Clock::ProcessAllSubscriptionActivitiesJob, job: true do
  subject { described_class }

  let(:matching_service) { UsageMonitoring::ProcessAllSubscriptionActivitiesService }

  describe ".perform" do
    before do
      allow(matching_service).to receive(:call!)
    end

    context "when premium features are enabled", :premium do
      it "calls matching service" do
        described_class.perform_now
        expect(matching_service).to have_received(:call!)
      end
    end

    it "does nothing" do
      described_class.perform_now
      expect(matching_service).not_to have_received(:call!)
    end
  end
end
