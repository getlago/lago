# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::ApplyService do
  subject(:apply_service) { described_class.new(subscription:, activation_rules:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, :pending, customer:, plan:, organization:) }

  describe "#call" do
    context "when subscription is not pending" do
      let(:subscription) { create(:subscription, customer:, plan:, organization:) }
      let(:activation_rules) { [{type: "payment", timeout_hours: 48}] }

      it "returns a validation failure" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.messages[:activation_rules]).to eq(["subscription_not_pending"])
      end
    end

    context "when activation_rules is nil" do
      let(:subscription) { create(:subscription, :pending, :with_activation_rules, customer:, plan:, organization:) }
      let(:activation_rules) { nil }

      it "does not change existing rules" do
        result = apply_service.call

        expect(result).to be_success
        expect(subscription.activation_rules.reload.count).to eq(1)
      end
    end

    context "when activation_rules is an empty array" do
      let(:subscription) { create(:subscription, :pending, :with_activation_rules, customer:, plan:, organization:) }
      let(:activation_rules) { [] }

      it "removes all existing rules" do
        result = apply_service.call

        expect(result).to be_success
        expect(result.activation_rules).to be_empty
        expect(subscription.activation_rules.reload).to be_empty
      end
    end

    context "when activation_rules has a payment rule" do
      let(:activation_rules) { [{type: "payment", timeout_hours: 48}] }

      it "creates the rule with inactive status" do
        result = apply_service.call

        expect(result).to be_success
        expect(result.activation_rules.count).to eq(1)
        expect(result.activation_rules.first).to have_attributes(
          id: String,
          subscription_id: subscription.id,
          type: "payment",
          timeout_hours: 48,
          status: "inactive",
          organization_id: organization.id
        )
      end
    end

    context "when activation_rules replaces existing rules" do
      let(:subscription) { create(:subscription, :pending, :with_activation_rules, customer:, plan:, organization:, activation_rules_config: [{type: "payment", timeout_hours: 48}]) }
      let(:activation_rules) { [{type: "payment", timeout_hours: 24}] }

      it "deletes old rules and creates new ones" do
        old_activation_rules = subscription.activation_rules.to_a

        result = apply_service.call

        expect(result).to be_success
        expect(old_activation_rules).to all(be_destroyed)
        expect(result.activation_rules.count).to eq(1)
        expect(result.activation_rules.first.timeout_hours).to eq(24)
      end
    end

    context "when timeout_hours is not provided" do
      let(:activation_rules) { [{type: "payment"}] }

      it "defaults timeout_hours to 0" do
        result = apply_service.call

        expect(result).to be_success
        expect(result.activation_rules.first.timeout_hours).to eq(0)
      end
    end
  end
end
