# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:customer_id) { customer.external_id }
  let(:paid_credits) { "1.00" }
  let(:granted_credits) { "0.00" }
  let(:expiration_at) { (Time.current + 1.year).iso8601 }
  let(:args) do
    {
      customer:,
      organization_id: organization.id,
      paid_credits:,
      granted_credits:,
      expiration_at:
    }
  end

  before { subscription }

  describe ".valid?" do
    it "returns true" do
      expect(validate_service).to be_valid
    end

    context "when organization_id is blank" do
      let(:args) do
        {
          customer:,
          organization_id: nil,
          paid_credits:,
          granted_credits:,
          expiration_at:
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:organization_id]).to eq(["blank"])
      end
    end

    context "when organization_id does not match customer's organization_id" do
      let(:other_organization) { create(:organization) }
      let(:args) do
        {
          customer:,
          organization_id: other_organization.id,
          paid_credits:,
          granted_credits:,
          expiration_at:
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:organization_id]).to eq(["invalid"])
      end
    end

    context "when customer does not exist" do
      let(:args) do
        {
          customer: nil,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:customer]).to eq(["customer_not_found"])
      end
    end

    context "with invalid paid_credits" do
      let(:paid_credits) { "foobar" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:paid_credits]).to eq(["invalid_paid_credits", "invalid_amount"])
      end
    end

    context "with invalid granted_credits" do
      let(:granted_credits) { "foobar" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:granted_credits]).to eq(["invalid_granted_credits", "invalid_amount"])
      end
    end

    context "with invalid expiration_at" do
      context "when string cannot be parsed to date" do
        let(:expiration_at) { "invalid" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
        end
      end

      context "when expiration_at is an integer" do
        let(:expiration_at) { 123 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
        end
      end

      context "when expiration_at is in the past" do
        let(:expiration_at) { (Time.current - 1.hour).iso8601 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
        end
      end

      context "when expiration_at is a valid datetime string but in the future" do
        let(:expiration_at) { (Time.current + 1.hour).iso8601 }

        it "returns true and has no errors" do
          expect(validate_service).to be_valid
        end
      end
    end

    context "with invalid transaction metadata" do
      let(:args) do
        {
          customer:,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          expiration_at:,
          transaction_metadata: [{key: "valid key", value1: "invalid value"}]
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:metadata]).to eq(["invalid_key_value_pair"])
      end
    end

    context "with recurring transaction rules" do
      let(:rules) do
        [
          {
            trigger: "interval",
            interval: "monthly"
          },
          {
            trigger: "threshold",
            threshold_credits: "-1.0"
          }
        ]
      end
      let(:args) do
        {
          customer:,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          recurring_transaction_rules: rules
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_number_of_recurring_rules"])
      end
    end

    context "with limitations" do
      let(:limitations) do
        {
          fee_types: %w[invalid charge]
        }
      end
      let(:args) do
        {
          customer:,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          applies_to: limitations
        }
      end

      it "returns false and result has errors if fee type is invalid" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:applies_to]).to eq(["invalid_limitations"])
      end

      context "with billable metric limitations" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:billable_metric_identifiers) { [billable_metric.id, "invalid"] }
        let(:limitations) do
          {
            billable_metric_ids: billable_metric_identifiers
          }
        end

        before do
          result.billable_metrics = [billable_metric]
          result.billable_metric_identifiers = billable_metric_identifiers
        end

        it "returns false and result has errors if BM is invalid" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:applies_to]).to eq(["invalid_limitations"])
        end
      end

      context "when limitations are valid" do
        let(:limitations) do
          {
            fee_types: %w[charge]
          }
        end

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end
    end

    context "with multiple wallets" do
      let(:max_wallets_limit) { Wallets::ValidateService::MAXIMUM_WALLETS_PER_CUSTOMER }

      describe "maximum wallets per customer" do
        it "is 6" do
          expect(max_wallets_limit).to eq(6)
        end
      end

      context "when number of wallets less than limit" do
        before do
          create_list(:wallet, max_wallets_limit - 2, customer:)
        end

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "when number of wallets equals limit" do
        before do
          create_list(:wallet, max_wallets_limit - 1, customer:)
        end

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "when number of wallets exceeds limit" do
        before do
          create_list(:wallet, max_wallets_limit, customer:)
        end

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:customer]).to eq(["wallet_limit_reached"])
        end
      end

      context "when org has setting of having more wallets per customer" do
        before do
          organization.update!(max_wallets: max_wallets_limit + 2)
        end

        context "when events_targeting_wallets premium integration is not enabled" do
          before do
            create_list(:wallet, max_wallets_limit + 1, customer:)
          end

          it "returns false and result has errors" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["wallet_limit_reached"])
          end
        end

        context "when events_targeting_wallets premium integration is enabled", :premium do
          before do
            organization.update!(premium_integrations: ["events_targeting_wallets"])
            create_list(:wallet, max_wallets_limit + 1, customer:)
          end

          it "returns true and result has no errors" do
            expect(validate_service).to be_valid
            expect(result.error).to be_nil
          end
        end
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
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
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
  end
end
