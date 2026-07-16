# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillPaidCreditJob do
  let(:wallet_transaction) { create(:wallet_transaction) }
  let(:timestamp) { Time.current.to_i }

  let(:invoice_service) { instance_double(Invoices::PaidCreditService) }
  let(:result) { BaseService::Result.new }

  let(:invoice) { nil }

  before do
    allow(Invoices::PaidCreditService).to receive(:call)
      .with(wallet_transaction:, timestamp:, invoice:)
      .and_return(result)
  end

  it "calls the paid credit service call method" do
    described_class.perform_now(wallet_transaction, timestamp)

    expect(Invoices::PaidCreditService).to have_received(:call)
  end

  context "when result is a failure" do
    let(:result) do
      BaseService::Result.new.single_validation_failure!(error_code: "error")
    end

    it "raises an error" do
      expect do
        described_class.perform_now(wallet_transaction, timestamp)
      end.to raise_error(BaseService::FailedResult)

      expect(Invoices::PaidCreditService).to have_received(:call)
    end

    context "with a previously created invoice" do
      let(:previous_invoice) { create(:invoice, :generating) }
      let(:invoice) { previous_invoice }

      it "raises an error" do
        expect do
          described_class.perform_now(wallet_transaction, timestamp, invoice: previous_invoice)
        end.to raise_error(BaseService::FailedResult)

        expect(Invoices::PaidCreditService).to have_received(:call)
      end
    end

    context "when a generating invoice is attached to the result" do
      let(:previous_invoice) { create(:invoice, :generating) }

      before { result.invoice = previous_invoice }

      it "retries the job with the invoice" do
        described_class.perform_now(wallet_transaction, timestamp)

        expect(Invoices::PaidCreditService).to have_received(:call)

        expect(described_class).to have_been_enqueued
          .with(wallet_transaction, timestamp, invoice: previous_invoice)
      end
    end

    context "when a not generating invoice is attached to the result" do
      let(:previous_invoice) { create(:invoice, :draft) }

      before { result.invoice = previous_invoice }

      it "raises an error" do
        expect do
          described_class.perform_now(wallet_transaction, timestamp)
        end.to raise_error(BaseService::FailedResult)

        expect(Invoices::PaidCreditService).to have_received(:call)
      end
    end
  end
end
