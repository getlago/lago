# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizeService do
  subject(:service) { described_class.new(invoice:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, :draft, customer:, organization:) }

  describe "#call" do
    context "when invoice is not yet finalized" do
      it "finalizes the invoice" do
        result = service.call

        expect(result).to be_success
        expect(result.invoice).to be_persisted
        expect(result.invoice.reload).to be_finalized
        expect(result.invoice.finalized_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when invoice is already finalized" do
      let(:invoice) do
        create(:invoice, :finalized, customer:, organization:, finalized_at:)
      end
      let(:finalized_at) { 2.days.ago }

      it "returns success without changes" do
        result = service.call

        expect(result).to be_success
        expect(result.invoice).to be_finalized
        expect(result.invoice.finalized_at).to eq(finalized_at)
      end
    end

    context "when invoice is nil" do
      let(:invoice) { nil }

      it "returns a not found failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("invoice")
      end
    end

    context "when invoice save fails" do
      before do
        allow(invoice).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(invoice))
      end

      it "returns a failure result" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
      end
    end
  end
end
