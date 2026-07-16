# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:payment_method) { create(:payment_method, organization:) }
  let(:payment_method_params) do
    {
      payment_method_id: payment_method.id,
      payment_method_type: "provider"
    }
  end
  let(:args) do
    {
      payment_method: payment_method_params
    }
  end

  describe ".valid?" do
    context "when there is no payment_method attribute" do
      let(:args) do
        {}
      end

      it "returns true" do
        expect(validate_service).to be_valid
      end
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
