# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::UpdateService do
  subject(:update_service) { described_class.new(fee:, params:) }

  let(:charge) { create(:standard_charge) }
  let(:old_date) { Time.current - 3.days }
  let(:fee) { create(:charge_fee, fee_type: "charge", pay_in_advance: true, invoice: nil, charge:, failed_at: old_date, succeeded_at: old_date, refunded_at: old_date) }

  let(:params) { {payment_status:} }
  let(:payment_status) { "succeeded" }

  describe "call" do
    it "updates the fee" do
      result = update_service.call

      expect(result).to be_success

      expect(result.fee.payment_status).to eq("succeeded")
      expect(result.fee.succeeded_at).to be_within(1.minute).of(Time.current)
      expect(result.fee.failed_at).to be_nil
      expect(result.fee.refunded_at).to be_nil
    end

    context "when fee is nil" do
      let(:fee) { nil }

      it "returns a not found failure" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("fee_not_found")
      end
    end

    context "when fee is part of an invoice" do
      let(:fee) { create(:charge_fee, fee_type: "charge", invoice: create(:invoice)) }

      it "returns a not allowed failure" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoiced_fee")
      end
    end

    context "when payment_status is invalid" do
      let(:payment_status) { "foo" }

      it "returns a validation failure" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:payment_status]).to eq(["value_is_invalid"])
      end
    end

    context "when payment_status is failed" do
      let(:payment_status) { "failed" }

      it "updates the fee" do
        result = update_service.call

        expect(result).to be_success

        expect(result.fee.payment_status).to eq("failed")
        expect(result.fee.failed_at).to be_within(1.minute).of(Time.current)
        expect(result.fee.refunded_at).to be_nil
        expect(result.fee.succeeded_at).to be_nil
      end
    end

    context "when payment_status is refunded" do
      let(:payment_status) { "refunded" }

      it "updates the fee" do
        result = update_service.call

        expect(result).to be_success

        expect(result.fee.payment_status).to eq("refunded")
        expect(result.fee.refunded_at).to be_within(1.minute).of(Time.current)
        expect(result.fee.succeeded_at).to be_nil
        expect(result.fee.failed_at).to be_nil
      end
    end
  end
end
