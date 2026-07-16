# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, payment_provider: "stripe") }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { nil }
  let(:subscription_type) { "create" }
  let(:activation_rules) { nil }
  let(:payment_method_params) { nil }

  let(:args) do
    {
      activation_rules:,
      subscription:,
      subscription_type:,
      payment_method: payment_method_params,
      customer:
    }
  end

  before { create(:payment_method, customer:, organization:) }

  describe "#valid?" do
    context "when activation_rules is an empty array" do
      let(:activation_rules) { [] }

      it { is_expected.to be_valid }
    end

    context "when activation_rules is a string" do
      let(:activation_rules) { "invalid" }

      it "is invalid with invalid_format error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:activation_rules]).to eq(["invalid_format"])
      end
    end

    context "when activation_rules is a hash" do
      let(:activation_rules) { {type: "payment"} }

      it "is invalid with invalid_format error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:activation_rules]).to eq(["invalid_format"])
      end
    end

    context "when subscription_type is update" do
      let(:subscription_type) { "update" }

      context "when subscription is pending" do
        let(:subscription) { create(:subscription, :pending, customer:, plan:, organization:) }
        let(:activation_rules) { [{type: "payment"}] }

        it { is_expected.to be_valid }
      end

      context "when subscription is active" do
        let(:subscription) { create(:subscription, customer:, plan:, organization:) }
        let(:activation_rules) { [{type: "payment"}] }

        it "is invalid with subscription_not_pending error" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:activation_rules]).to eq(["subscription_not_pending"])
        end
      end
    end

    context "when subscription is nil" do
      let(:activation_rules) { [{type: "payment", timeout_hours: 24}] }

      it { is_expected.to be_valid }
    end

    context "with valid payment rule" do
      let(:activation_rules) { [{type: "payment", timeout_hours: 48}] }

      it { is_expected.to be_valid }
    end

    context "with unknown rule type" do
      let(:activation_rules) { [{type: "unknown"}] }

      it "is invalid with invalid_type error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:activation_rules]).to eq(["invalid_type"])
      end
    end

    context "with duplicate rule types" do
      let(:activation_rules) { [{type: "payment", timeout_hours: 24}, {type: "payment", timeout_hours: 48}] }

      it "is invalid with duplicated_type error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:activation_rules]).to eq(["duplicated_type"])
      end
    end

    context "with multiple rules including unknown type" do
      let(:activation_rules) { [{type: "payment", timeout_hours: 48}, {type: "unknown"}] }

      it "is invalid with invalid_type error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:activation_rules]).to eq(["invalid_type"])
      end
    end
  end
end
