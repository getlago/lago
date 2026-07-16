# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::EvaluateService do
  subject(:result) { described_class.call(subscription:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true) }
  let(:subscription) { create(:subscription, :incomplete, organization:, customer:, plan:) }

  context "when subscription has an inactive payment activation rule" do
    let(:rule) { create(:payment_subscription_activation_rule, subscription:) }

    before { rule }

    it "evaluates the rule to pending" do
      expect(result).to be_success
      expect(result.rules.first).to be_pending
    end
  end

  context "when subscription has no activation rules" do
    it "returns success with empty rules" do
      expect(result).to be_success
      expect(result.rules).to be_empty
    end
  end

  context "when subscription has a payment rule that is not applicable" do
    let(:plan) { create(:plan, organization:, pay_in_advance: false) }
    let(:rule) { create(:payment_subscription_activation_rule, subscription:) }

    before { rule }

    it "evaluates the rule to not_applicable" do
      expect(result).to be_success
      expect(result.rules.first).to be_not_applicable
    end
  end

  context "when rules are already in a terminal state" do
    let(:rule) { create(:payment_subscription_activation_rule, subscription:, status: "satisfied") }

    before { rule }

    it "does not change rule status" do
      expect(result).to be_success
      expect(result.rules.first).to be_satisfied
    end

    it "does not change subscription status" do
      expect(result.subscription).to be_incomplete
    end
  end
end
