# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizeBatchService do
  subject(:finalize_batch_service) { described_class.new(organization:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }

  describe "#call_async" do
    it "enqueues a job to finalize all draft invoices" do
      expect do
        finalize_batch_service.call_async
      end.to have_enqueued_job(Invoices::FinalizeAllJob)
    end
  end

  describe "#call" do
    let(:finalize_service) { instance_double(Invoices::RefreshDraftAndFinalizeService) }
    let(:result) { BaseService::Result.new }
    let(:invoice_ids) { invoices.map(&:id) }
    let(:invoices) { create_list(:invoice, 3, status: "draft", customer:) }

    before do
      invoices

      result.invoice = Invoice.new

      allow(Invoices::RefreshDraftAndFinalizeService).to receive(:new).and_return(finalize_service)
      allow(finalize_service).to receive(:call).and_return(result)
    end

    it "returns processed invoices that have correct status" do
      result = finalize_batch_service.call(invoice_ids)

      expect(result).to be_success
      expect(result.invoices.count).to eq(3)
    end

    context "when inner service passes error result" do
      before do
        result.fail_with_error!(BaseService::MethodNotAllowedFailure.new(result, code: "error"))
      end

      it "returns an error" do
        result = finalize_batch_service.call(invoice_ids)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("error")
      end
    end
  end
end
