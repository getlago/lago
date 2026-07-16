# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessSubscriptionActivityJob do
  describe "#perform" do
    let(:subscription_activity) { create(:subscription_activity) }
    let(:subscription_activity_id) { subscription_activity.id }

    before do
      allow(UsageMonitoring::ProcessSubscriptionActivityService).to receive(:call!)
    end

    it "calls the ProcessSubscriptionActivityService with the subscription activity" do
      described_class.perform_now(subscription_activity_id)
      expect(UsageMonitoring::ProcessSubscriptionActivityService).to have_received(:call!).with(subscription_activity:)
    end

    context "when the subscription activity does not exist" do
      let(:subscription_activity_id) { 9_999_999_999_999 }

      it "does not call the ProcessSubscriptionActivityService" do
        expect(UsageMonitoring::ProcessSubscriptionActivityService).not_to have_received(:call!)
        described_class.perform_now(subscription_activity_id)
      end
    end

    context "when ProcessSubscriptionActivityService raises" do
      before do
        allow(described_class).to receive(:perform_later)
        allow(UsageMonitoring::ProcessSubscriptionActivityService).to receive(:call!).and_raise(BaseService::ThrottlingError)
      end

      it "re-enqueues the job" do
        described_class.perform_now(subscription_activity_id)
        expect(described_class).to have_received(:perform_later).with(subscription_activity_id, 2)
      end

      context "when the max retries is reached" do
        it "removes the SubscriptionActivity" do
          begin
            described_class.perform_now(subscription_activity_id, 4)
          rescue BaseService::ThrottlingError => _e
          end
          expect(described_class).not_to have_received(:perform_later)
          expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
