# frozen_string_literal: true

require "rails_helper"

describe Clock::ExpireIncompleteSubscriptionsJob, job: true do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true) }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    let(:expirable_subscription) { create(:subscription, :incomplete, customer:, organization:, plan:) }
    let(:non_expirable_pending_subscription) { create(:subscription, :incomplete, customer:, organization:, plan:) }
    let(:active_subscription) { create(:subscription, :active, customer:, organization:, plan:) }

    before do
      # Expirable: incomplete + pending payment rule + expires_at in the past
      create(:subscription_activation_rule, subscription: expirable_subscription, organization:,
        status: "pending", timeout_hours: 48, expires_at: 1.hour.ago)

      # Incomplete sub but rule is still in the future window — not yet expirable
      create(:subscription_activation_rule, subscription: non_expirable_pending_subscription, organization:,
        status: "pending", timeout_hours: 48, expires_at: 12.hours.from_now)

      # Active sub with a satisfied rule — should never be picked up
      create(:subscription_activation_rule, subscription: active_subscription, organization:,
        status: "satisfied", timeout_hours: 48, expires_at: 1.hour.ago)
    end

    it "enqueues an ExpireIncompleteJob for each expirable subscription" do
      described_class.perform_now

      expect(Subscriptions::ActivationRules::ExpireIncompleteJob)
        .to have_been_enqueued.with(expirable_subscription)
    end

    it "does not enqueue for subscriptions whose rule has not expired yet" do
      described_class.perform_now

      expect(Subscriptions::ActivationRules::ExpireIncompleteJob)
        .not_to have_been_enqueued.with(non_expirable_pending_subscription)
    end

    it "does not enqueue for non-incomplete subscriptions" do
      described_class.perform_now

      expect(Subscriptions::ActivationRules::ExpireIncompleteJob)
        .not_to have_been_enqueued.with(active_subscription)
    end
  end
end
