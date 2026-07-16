# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizePendingViesInvoiceJob do
  let(:invoice) { create(:invoice, :pending, tax_status: "pending") }
  let(:result) { BaseService::Result.new }

  describe "#perform" do
    before do
      allow(Invoices::FinalizePendingViesInvoiceService).to receive(:call!)
        .with(invoice:)
        .and_return(result)
    end

    it "delegates to the FinalizePendingViesInvoiceService" do
      described_class.perform_now(invoice)

      expect(Invoices::FinalizePendingViesInvoiceService).to have_received(:call!).with(invoice:)
    end
  end

  describe "retry_on" do
    [
      [Customers::FailedToAcquireLock.new("customer-1-prepaid_credit"), 25],
      [ActiveRecord::StaleObjectError.new("Attempted to update a stale object: Wallet."), 25]
    ].each do |error, attempts|
      error_class = error.class

      context "when a #{error_class} error is raised" do
        before do
          allow(Invoices::FinalizePendingViesInvoiceService).to receive(:call).and_raise(error)
        end

        it "raises a #{error_class.name} error and retries" do
          assert_performed_jobs(attempts, only: [described_class]) do
            expect do
              described_class.perform_later(invoice)
            end.to raise_error(error_class)
          end
        end
      end
    end
  end
end
