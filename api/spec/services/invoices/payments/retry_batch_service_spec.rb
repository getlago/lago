# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::RetryBatchService do
  subject(:retry_batch_service) { described_class.new(organization_id: organization.id) }

  let(:customer) { create(:customer, payment_provider: "stripe") }
  let(:organization) { customer.organization }

  describe "#call_async" do
    it "enqueues a job to retry all payments" do
      expect do
        retry_batch_service.call_async
      end.to have_enqueued_job(Invoices::Payments::RetryAllJob)
    end
  end

  describe "#call" do
    let(:invoice_ids) { [invoice_first.id, invoice_second.id] }
    let(:invoice_first) do
      create(
        :invoice,
        customer:,
        status: "finalized",
        payment_status: "failed",
        ready_for_payment_processing: true
      )
    end
    let(:invoice_second) do
      create(
        :invoice,
        customer:,
        status: "finalized",
        payment_status: "failed",
        ready_for_payment_processing: true
      )
    end
    let(:invoice_third) do
      create(
        :invoice,
        customer:,
        status: "draft",
        ready_for_payment_processing: true
      )
    end

    before do
      invoice_first
      invoice_second
      invoice_third
    end

    it "returns processed invoices that have correct status and payment status" do
      result = retry_batch_service.call(invoice_ids)

      expect(result).to be_success
      expect(result.invoices.count).to eq(2)

      processed_ids = result.invoices.pluck(:id)

      expect(processed_ids).to include(invoice_first.id)
      expect(processed_ids).to include(invoice_second.id)
      expect(processed_ids).not_to include(invoice_third.id)
    end

    context "when inner service passes error result" do
      let(:invoice_second) do
        create(
          :invoice,
          customer:,
          status: "finalized",
          payment_status: "failed",
          ready_for_payment_processing: false
        )
      end

      it "returns an error" do
        result = retry_batch_service.call(invoice_ids)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("payment_processor_is_currently_handling_payment")
      end
    end
  end
end
