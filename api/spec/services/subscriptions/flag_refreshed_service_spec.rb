# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::FlagRefreshedService, :premium do
  let(:organization) { create(:organization, premium_integrations: %w[lifetime_usage]) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }

  before do
    allow(UsageMonitoring::TrackSubscriptionActivityService).to receive(:call).and_call_original
    create(:wallet, customer:, organization:)
  end

  describe "#call" do
    subject(:result) { described_class.call(subscription.id) }

    it "marks customer as awaiting wallet refresh" do
      expect { subject }.to change { customer.reload.awaiting_wallet_refresh }.from(false).to(true)
      expect(result).to be_success
    end

    it "tracks subscription activity" do
      subject
      expect(result).to be_success
      expect(subscription.subscription_activity).to be_present
      expected_date = Time.current.in_time_zone(customer.applicable_timezone).to_date
      expect(UsageMonitoring::TrackSubscriptionActivityService).to have_received(:call).with(subscription:, date: expected_date)
    end
  end
end
