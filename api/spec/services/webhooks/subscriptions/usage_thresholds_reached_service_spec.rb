# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::UsageThresholdsReachedService do
  subject(:webhook_service) { described_class.new(object: subscription, options: {usage_threshold:}) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization: organization) }
  let(:customer) { create(:customer, organization: organization) }
  let(:subscription) { create(:subscription, plan: plan, customer: customer) }
  let(:usage_threshold) { create(:usage_threshold, plan: plan) }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.usage_threshold_reached", "subscription", {
      "usage_threshold" => Hash,
      "applicable_usage_thresholds" => Array
    }
  end
end
