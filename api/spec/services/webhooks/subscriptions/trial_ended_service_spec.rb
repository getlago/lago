# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::TrialEndedService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:subscription) { create(:subscription, plan: create(:plan, trial_period: 1)) }
  let(:organization) { subscription.organization }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.trial_ended", "subscription"
  end
end
