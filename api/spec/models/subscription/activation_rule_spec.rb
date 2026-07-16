# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::ActivationRule do
  subject(:activation_rule) { create(:subscription_activation_rule) }

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:status)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(
          inactive: "inactive",
          pending: "pending",
          satisfied: "satisfied",
          declined: "declined",
          failed: "failed",
          expired: "expired",
          not_applicable: "not_applicable"
        )
      expect(subject).to define_enum_for(:type)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(payment: "payment")
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:subscription)
      expect(subject).to belong_to(:organization)
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:type)
      expect(subject).to validate_inclusion_of(:type).in_array(Subscription::ActivationRule::STI_MAPPING.keys)
    end
  end

  describe "Scopes" do
    describe ".fulfilled" do
      let(:satisfied_rule) { create(:subscription_activation_rule, status: "satisfied") }
      let(:not_applicable_rule) { create(:subscription_activation_rule, status: "not_applicable") }

      before do
        satisfied_rule
        not_applicable_rule
        create(:subscription_activation_rule, status: "pending")
        create(:subscription_activation_rule, status: "failed")
      end

      it "returns only satisfied and not_applicable rules" do
        expect(described_class.fulfilled).to match_array([satisfied_rule, not_applicable_rule])
      end
    end

    describe ".rejected" do
      let(:failed_rule) { create(:subscription_activation_rule, status: "failed") }
      let(:expired_rule) { create(:subscription_activation_rule, status: "expired") }
      let(:declined_rule) { create(:subscription_activation_rule, status: "declined") }

      before do
        failed_rule
        expired_rule
        declined_rule
        create(:subscription_activation_rule, status: "pending")
        create(:subscription_activation_rule, status: "satisfied")
      end

      it "returns only failed, expired, and declined rules" do
        expect(described_class.rejected).to match_array([failed_rule, expired_rule, declined_rule])
      end
    end

    describe ".expirable" do
      let(:expirable_rule) { create(:subscription_activation_rule, status: "pending", expires_at: 1.hour.ago) }

      before do
        expirable_rule
        create(:subscription_activation_rule, status: "pending", expires_at: 1.hour.from_now)
        create(:subscription_activation_rule, status: "inactive", expires_at: 1.hour.ago)
      end

      it "returns only pending rules past their expiry" do
        expect(described_class.expirable).to eq([expirable_rule])
      end
    end
  end

  describe ".find_sti_class" do
    it "resolves payment to Subscription::ActivationRule::Payment" do
      expect(described_class.find_sti_class("payment")).to eq(Subscription::ActivationRule::Payment)
    end

    it "raises KeyError for unknown type" do
      expect { described_class.find_sti_class("unknown") }.to raise_error(KeyError)
    end
  end

  describe ".sti_name" do
    it "returns payment for Subscription::ActivationRule::Payment" do
      expect(Subscription::ActivationRule::Payment.sti_name).to eq("payment")
    end
  end

  describe "#applicable?" do
    it "raises NotImplementedError on the base class" do
      rule = described_class.new
      expect { rule.applicable? }.to raise_error(NotImplementedError)
    end
  end

  describe "#evaluate!" do
    it "calls the type-specific EvaluateService" do
      allow(Subscriptions::ActivationRules::Payment::EvaluateService).to receive(:call!)

      activation_rule.evaluate!

      expect(Subscriptions::ActivationRules::Payment::EvaluateService)
        .to have_received(:call!).with(rule: activation_rule)
    end
  end
end
