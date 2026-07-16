# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::TrackSubscriptionActivityService, :premium do
  subject { described_class.new(organization:, subscription:, date:) }

  let(:organization) { create(:organization, premium_integrations: %w[lifetime_usage]) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:date) { Date.new(2025, 1, 15) }

  context "when the plan has usage_thresholds" do
    it "tracks activity" do
      create(:usage_threshold, plan: subscription.plan)
      expect { subject.call }.to change { organization.subscription_activities.count }.by(1)
      expect { subject.call }.not_to change { organization.subscription_activities.count }
    end

    it "sets last_received_event_on" do
      create(:usage_threshold, plan: subscription.plan)
      expect { subject.call }.to change { subscription.reload.last_received_event_on }.from(nil).to(date)
    end
  end

  context "when last_received_event_on is already set to the same date" do
    before { subscription.update(last_received_event_on: date) }

    it "does not update the subscription" do
      expect { subject.call }.not_to change { subscription.reload.updated_at }
    end
  end

  context "when organization does use any integration with subscription tracking" do
    let(:organization) { create(:organization, premium_integrations: %w[salesforce]) }

    it "does not track activity" do
      subject.call
      expect(organization.subscription_activities.count).to eq(0)
    end
  end

  context "when subscription isn't active" do
    let(:subscription) { create(:subscription, :terminated, customer:) }

    it "does not track activity" do
      subject.call
      expect(organization.subscription_activities.count).to eq(0)
    end

    it "does not set last_received_event_on" do
      subject.call
      expect(subscription.reload.last_received_event_on).to be_nil
    end
  end

  context "when license is not premium" do
    it "does not set last_received_event_on" do
      allow(License).to receive(:premium?).and_return(false)
      subject.call
      expect(subscription.reload.last_received_event_on).to be_nil
    end
  end
end
