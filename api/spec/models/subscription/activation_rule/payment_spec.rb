# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::ActivationRule::Payment do
  subject(:rule) { build(:subscription_activation_rule, subscription:, timeout_hours:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, :with_stripe_payment_provider, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, organization:) }
  let(:timeout_hours) { 48 }

  describe "#applicable?" do
    context "when plan is pay in advance and not in trial" do
      let(:plan) { create(:plan, :pay_in_advance, organization:) }

      it "returns true" do
        expect(rule.applicable?).to be(true)
      end
    end

    context "when plan is pay in arrears with no pay in advance fixed charges" do
      it "returns false" do
        expect(rule.applicable?).to be(false)
      end
    end

    context "when plan has a trial period and is pay in advance" do
      let(:plan) { create(:plan, :pay_in_advance, trial_period: 30, organization:) }

      it "returns false" do
        expect(rule.applicable?).to be(false)
      end
    end

    context "when plan has a trial period but has pay in advance fixed charges" do
      let(:plan) { create(:plan, trial_period: 30, organization:) }

      before { create(:fixed_charge, :pay_in_advance, plan:) }

      it "returns true" do
        expect(rule.applicable?).to be(true)
      end
    end

    context "when plan has pay in advance fixed charges" do
      before { create(:fixed_charge, :pay_in_advance, plan:) }

      it "returns true" do
        expect(rule.applicable?).to be(true)
      end
    end
  end
end
