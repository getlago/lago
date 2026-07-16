# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::RetryBatchService do
  subject(:retry_batch_service) { described_class.new(organization:) }

  let(:customer) { create(:customer, payment_provider: "stripe") }
  let(:organization) { customer.organization }

  describe "#call_async" do
    it "enqueues a job to retry all payments" do
      expect do
        retry_batch_service.call_async
      end.to have_enqueued_job(Invoices::RetryAllJob)
    end
  end

  describe "#call" do
    let(:retry_service) { instance_double(Invoices::RetryService) }
    let(:result) { BaseService::Result.new }
    let(:invoice_ids) { [invoice_first.id, invoice_second.id] }
    let(:invoice_first) do
      create(
        :invoice,
        customer:,
        status: "failed"
      )
    end
    let(:invoice_second) do
      create(
        :invoice,
        customer:,
        status: "failed"
      )
    end
    let(:invoice_third) do
      create(
        :invoice,
        customer:,
        status: "draft"
      )
    end

    before do
      invoice_first
      invoice_second
      invoice_third

      result.invoice = Invoice.new

      allow(Invoices::RetryService).to receive(:new).and_return(retry_service)
      allow(retry_service).to receive(:call).and_return(result)
    end

    it "returns processed invoices that have correct status" do
      result = retry_batch_service.call(invoice_ids)

      expect(result).to be_success
      expect(result.invoices.count).to eq(2)
    end

    context "when inner service passes error result" do
      before do
        result.fail_with_error!(BaseService::MethodNotAllowedFailure.new(result, code: "error"))
      end

      it "returns an error" do
        result = retry_batch_service.call(invoice_ids)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("error")
      end
    end
  end
end
