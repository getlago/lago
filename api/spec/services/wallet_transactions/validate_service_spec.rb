# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:) }
  let(:wallet_id) { wallet.id }
  let(:paid_credits) { "1.00" }
  let(:granted_credits) { "0.00" }
  let(:voided_credits) { "0.00" }
  let(:args) do
    {
      wallet_id:,
      customer_id: customer.external_id,
      organization_id: organization.id,
      paid_credits:,
      granted_credits:,
      voided_credits:,
      **((name == :undefined) ? {} : {name:})
    }
  end
  let(:name) { :undefined }

  before { subscription }

  describe ".valid?" do
    it "returns true" do
      expect(validate_service).to be_valid
    end

    context "when wallet does not exists" do
      let(:wallet_id) { "123456" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:wallet_id]).to eq(["wallet_not_found"])
      end
    end

    context "when customer is provided" do
      let(:args) do
        {
          wallet_id:,
          customer:,
          organization:,
          paid_credits:,
          granted_credits:,
          voided_credits:
        }
      end

      it "returns true when wallet belongs to the customer" do
        expect(validate_service).to be_valid
      end

      context "when wallet belongs to another customer" do
        let(:other_customer) { create(:customer, organization:) }
        let(:other_wallet) { create(:wallet, customer: other_customer) }
        let(:wallet_id) { other_wallet.id }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:wallet_id]).to eq(["wallet_not_found"])
        end
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

    [
      :voided_credits,
      :granted_credits,
      :paid_credits
    ].each do |attr|
      context "with #{attr} >= 10^25" do
        let(attr) { 10**25 }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[attr]).to eq(["invalid_#{attr}", "invalid_amount"])
        end
      end

      context "with #{attr} < 0" do
        let(attr) { "-1.00" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[attr]).to eq(["invalid_#{attr}", "invalid_amount"])
        end
      end

      context "with #{attr} < 10^25" do
        let(attr) { (10**25 - 1).to_s }
        let(:wallet) { create(:wallet, customer:, credits_balance: 10**25 - 1) }

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "with #{attr} = 0" do
        let(attr) { "0.00" }

        it "returns true and result has no errors" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end
    end

    context "when inbound credits round to zero monetary value" do
      let(:wallet) { create(:wallet, customer:, rate_amount: "0.01", credits_balance: 10) }

      context "with paid_credits that round to zero" do
        let(:paid_credits) { "0.4" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:paid_credits]).to eq(["amount_rounds_to_zero"])
        end
      end

      context "with granted_credits that round to zero" do
        let(:paid_credits) { "0.0" }
        let(:granted_credits) { "0.4" }

        it "returns false and result has errors" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:granted_credits]).to eq(["amount_rounds_to_zero"])
        end
      end

      context "when the credits produce a non-zero monetary value" do
        let(:paid_credits) { "1.0" }

        it "returns true" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "with strictly-zero credits" do
        let(:paid_credits) { "0.0" }
        let(:granted_credits) { "0.0" }

        it "returns true and preserves the existing no-op behavior" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end

      context "with voided_credits that round to zero" do
        let(:paid_credits) { "0.0" }
        let(:granted_credits) { "0.0" }
        let(:voided_credits) { "0.4" }

        it "returns true since outbound transactions are unaffected" do
          expect(validate_service).to be_valid
          expect(result.error).to be_nil
        end
      end
    end

    context "when the wallet uses a three-decimal currency" do
      let(:wallet) { create(:wallet, customer:, currency: "KWD", rate_amount: "0.001", credits_balance: 10) }
      let(:paid_credits) { "1.0" }

      it "keeps a sub-cent but non-zero monetary value valid" do
        expect(validate_service).to be_valid
        expect(result.error).to be_nil
      end
    end

    context "with invalid voided_credits" do
      let(:voided_credits) { "foobar" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:voided_credits]).to eq(["invalid_voided_credits", "invalid_amount"])
      end
    end

    context "with valid voided_credits but insufficient credits" do
      let(:voided_credits) { "1.00" }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:voided_credits]).to eq(["insufficient_credits"])
      end
    end

    context "with invalid metadata" do
      let(:args) do
        {
          wallet_id:,
          customer_id: customer.external_id,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          metadata: [{"key" => "key", "value" => {"key" => "nested_value"}}]
        }
      end

      it "returns false and result has errors for metadata" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:metadata]).to eq(["nested_structure_not_allowed"])
      end
    end

    context "with the maximum number of metadata key-value pairs" do
      let(:args) do
        {
          wallet_id:,
          customer_id: customer.external_id,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          metadata: (1..15).map { |i| {"key" => "key#{i}", "value" => "value#{i}"} }
        }
      end

      it "returns true" do
        expect(validate_service).to be_valid
        expect(result.error).to be_nil
      end
    end

    context "with too many metadata key-value pairs" do
      let(:args) do
        {
          wallet_id:,
          customer_id: customer.external_id,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          metadata: (1..16).map { |i| {"key" => "key#{i}", "value" => "value#{i}"} }
        }
      end

      it "returns false and result has errors for metadata" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:metadata]).to eq(["too_many_keys"])
      end
    end

    context "with valid name" do
      let(:name) { "Valid Transaction Name" }

      it { is_expected.to be_valid }
    end

    context "with blank name" do
      let(:name) { "" }

      it { is_expected.to be_valid }
    end

    context "with nil name" do
      let(:name) { nil }

      it { is_expected.to be_valid }
    end

    context "with name at maximum length" do
      let(:name) { "a" * 255 }

      it { is_expected.to be_valid }
    end

    context "with name that is too long" do
      let(:name) { "a" * 256 }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:name]).to eq(["too_long"])
      end
    end

    context "with name that is not a string" do
      let(:name) { 123 }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:name]).to eq(["invalid_value"])
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
          wallet_id:,
          customer_id: customer.external_id,
          organization_id: organization.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          payment_method: payment_method_params,
          **((name == :undefined) ? {} : {name:})
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
