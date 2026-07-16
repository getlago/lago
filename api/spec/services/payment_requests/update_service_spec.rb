# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::UpdateService do
  subject(:result) do
    described_class.call(
      payable: payment_request,
      params: update_args,
      webhook_notification:
    )
  end

  let(:payment_request) { create :payment_request }
  let(:webhook_notification) { false }
  let(:update_args) { {payment_status: "succeeded"} }

  describe "#call" do
    it "updates the invoice" do
      expect(result).to be_success
      expect(result.payable).to eq(payment_request)
      expect(result.payable).to be_payment_succeeded
    end

    context "when payment_request does not exist" do
      let(:payment_request) { nil }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("payment_request_not_found")
      end
    end
  end
end
