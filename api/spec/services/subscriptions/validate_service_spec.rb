# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription_at) { Time.current.iso8601 }
  let(:ending_at) { (Time.current + 1.year).iso8601 }

  let(:args) do
    {
      customer:,
      plan:,
      subscription_at:,
      ending_at:,
      on_termination_credit_note:,
      on_termination_invoice:,
      subscription:,
      subscription_type:
    }
  end

  let(:on_termination_credit_note) { nil }
  let(:on_termination_invoice) { nil }
  let(:subscription) { nil }
  let(:subscription_type) { "create" }

  describe "#ending_at" do
    subject(:method_call) { validate_service.__send__(:ending_at) }

    context "when date contains milliseconds" do
      let(:ending_at) { "2020-01-01T00:00:00.123Z" }

      it "returns the date" do
        expect(subject).to eq(DateTime.iso8601(ending_at))
      end
    end

    context "when date does not contain milliseconds" do
      let(:ending_at) { "2020-01-01T00:00:00Z" }

      it "returns the date" do
        expect(subject).to eq(DateTime.iso8601(ending_at))
      end
    end
  end

  describe "#subscription_at" do
    subject(:method_call) { validate_service.__send__(:subscription_at) }

    context "when date contains milliseconds" do
      let(:subscription_at) { "2021-02-01T00:00:00.123Z" }

      it "returns the date" do
        expect(subject).to eq(DateTime.iso8601(subscription_at))
      end
    end

    context "when date does not contain milliseconds" do
      let(:subscription_at) { "2020-01-01T00:00:00Z" }

      it "returns the date" do
        expect(subject).to eq(DateTime.iso8601(subscription_at))
      end
    end
  end

  describe ".valid?" do
    it "returns true" do
      expect(validate_service).to be_valid
    end

    context "when customer does not exist" do
      let(:customer) { nil }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when plan does not exist" do
      let(:plan) { nil }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("plan_not_found")
      end
    end

    context "with invalid subscription_at" do
      context "when string is not a valid iso8601 datetime" do
        let(:subscription_at) { "2022-12-13 12:00:00Z" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:subscription_at]).to eq(["invalid_date"])
        end
      end

      context "when subscription_at is integer" do
        let(:subscription_at) { 123 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:subscription_at]).to eq(["invalid_date"])
        end
      end

      context "when subscription_at raises a bare ArgumentError while parsing" do
        let(:subscription_at) { "1" * 129 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:subscription_at]).to eq(["invalid_date"])
        end
      end

      context "when subscription_at is in ISO8601 week-date format" do
        let(:subscription_at) { "2022-W50-2" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:subscription_at]).to eq(["invalid_date"])
        end
      end
    end

    context "with invalid ending_at" do
      context "when string cannot be parsed to date" do
        let(:ending_at) { "invalid" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at is integer" do
        let(:ending_at) { 123 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at raises a bare ArgumentError while parsing" do
        let(:ending_at) { "1" * 129 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at is in ISO8601 week-date format" do
        let(:ending_at) { "2099-W50-2" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at uses an invalid date format" do
        let(:ending_at) { "2025-08-20T16:11:39.061+02:00" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at is less than subscription_at and current time" do
        let(:ending_at) { (Time.current - 1.year).iso8601 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at is in the future but not after subscription_at" do
        let(:subscription_at) { (Time.current + 2.years).iso8601 }
        let(:ending_at) { (Time.current + 1.year).iso8601 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end

      context "when ending_at is valid but subscription_at uses an invalid format" do
        let(:subscription_at) { "2022-W50-2" }
        let(:ending_at) { (Time.current + 1.year).iso8601 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:ending_at]).to eq(["invalid_date"])
        end
      end
    end

    context "with invalid on_termination_credit_note" do
      let(:on_termination_credit_note) { "invalid" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:on_termination_credit_note]).to eq(["invalid_value"])
      end
    end

    context "with valid on_termination_credit_note" do
      let(:on_termination_credit_note) { "credit" }

      it "returns true" do
        expect(validate_service).to be_valid
      end
    end

    context "with invalid on_termination_invoice" do
      let(:on_termination_invoice) { "invalid" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:on_termination_invoice]).to eq(["invalid_value"])
      end
    end

    context "with valid on_termination_invoice" do
      let(:on_termination_invoice) { "generate" }

      it "returns true" do
        expect(validate_service).to be_valid
      end
    end

    context "with valid on_termination_invoice skip" do
      let(:on_termination_invoice) { "skip" }

      it "returns true" do
        expect(validate_service).to be_valid
      end
    end

    context "with payment method" do
      let(:payment_method) { create(:payment_method, customer:, organization:) }
      let(:payment_method_params) do
        {
          payment_method_id: payment_method.id,
          payment_method_type: "provider"
        }
      end
      let(:args) do
        {
          customer:,
          plan:,
          subscription_at:,
          ending_at:,
          on_termination_credit_note:,
          on_termination_invoice:,
          payment_method: payment_method_params
        }
      end

      context "when provider payment method is valid" do
        before do
          result.payment_method = payment_method
        end

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "when manual payment method is valid" do
        let(:payment_method_params) do
          {
            payment_method_type: "manual"
          }
        end

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "with invalid payment method type" do
        let(:payment_method_params) do
          {
            payment_method_id: payment_method.id,
            payment_method_type: "invalid"
          }
        end

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end

      context "with invalid payment method reference" do
        let(:payment_method_params) do
          {
            payment_method_id: "invalid",
            payment_method_type: "provider"
          }
        end

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end
    end

    context "with activation_rules" do
      let(:args) do
        {
          customer:,
          plan:,
          subscription_at:,
          ending_at:,
          on_termination_credit_note:,
          on_termination_invoice:,
          subscription:,
          subscription_type:,
          activation_rules:
        }
      end

      let(:customer) { create(:customer, organization:, payment_provider: "stripe") }

      context "when activation_rules contains valid payment rule" do
        let(:activation_rules) { [{type: "payment", timeout_hours: 48}] }

        before { create(:payment_method, customer:, organization:) }

        it { is_expected.to be_valid }
      end

      context "when activation_rules contains invalid rule" do
        let(:activation_rules) { [{type: "unknown", timeout_hours: 48}] }

        it "is invalid with invalid_type error" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:activation_rules]).to eq(["invalid_type"])
        end
      end
    end
  end
end
