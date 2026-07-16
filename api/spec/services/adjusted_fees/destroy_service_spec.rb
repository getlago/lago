# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdjustedFees::DestroyService do
  subject(:destroy_service) { described_class.new(fee:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invoice) { create(:invoice, status: :draft, organization:) }
  let(:fee) { create(:charge_fee, invoice:) }
  let(:adjusted_fee) { create(:adjusted_fee, invoice:, fee:) }

  describe "#call" do
    before do
      adjusted_fee
      allow(Invoices::RefreshDraftService)
        .to receive(:call).with(invoice:)
        .and_return(BaseService::Result.new)
    end

    it "destroys the adjusted fee" do
      expect { destroy_service.call }.to change(AdjustedFee, :count).by(-1)
    end

    it "calls the RefreshDraft service" do
      destroy_service.call

      expect(Invoices::RefreshDraftService).to have_received(:call)
    end

    context "when adjusted fee is not found" do
      before { adjusted_fee.update!(fee: nil) }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("adjusted_fee_not_found")
      end
    end

    context "when fee is not found" do
      let(:fee) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("fee_not_found")
      end
    end
  end
end
