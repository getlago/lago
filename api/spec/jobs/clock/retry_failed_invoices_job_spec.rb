# frozen_string_literal: true

require "rails_helper"

describe Clock::RetryFailedInvoicesJob, job: true do
  subject { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    let(:customer) { create(:customer) }
    let(:failed_invoice) do
      create(
        :invoice,
        status: :failed,
        created_at: DateTime.parse("20 Jun 2022"),
        customer:,
        organization: customer.organization
      )
    end
    let(:error_detail) do
      create(
        :error_detail,
        owner: failed_invoice,
        organization: customer.organization,
        error_code: :tax_error,
        details: {
          tax_error: "validationError",
          tax_error_message: "You've exceeded your API limit of 10 per second"
        }
      )
    end
    let(:finalized_invoice) do
      create(
        :invoice,
        status: :finalized,
        created_at: DateTime.parse("20 Jun 2022"),
        customer:,
        organization: customer.organization
      )
    end

    before do
      failed_invoice
      finalized_invoice
      error_detail
      allow(Invoices::RetryService).to receive(:call)
    end

    context "with invalid product error" do
      let(:error_detail) do
        create(
          :error_detail,
          owner: failed_invoice,
          organization: customer.organization,
          error_code: :tax_error,
          details: {
            tax_error: "productExternalIdUnknown"
          }
        )
      end

      it "does not call the retry service" do
        current_date = DateTime.parse("22 Jun 2022")

        travel_to(current_date) do
          described_class.perform_now

          expect(Invoices::RetryService).not_to have_received(:call).with(invoice: failed_invoice)
          expect(Invoices::RetryService).not_to have_received(:call).with(invoice: finalized_invoice)
        end
      end
    end

    context "with api limit error" do
      it "calls the retry service" do
        current_date = DateTime.parse("22 Jun 2022")

        travel_to(current_date) do
          described_class.perform_now

          expect(Invoices::RetryService).to have_received(:call).with(invoice: failed_invoice)
          expect(Invoices::RetryService).not_to have_received(:call).with(invoice: finalized_invoice)
        end
      end
    end
  end
end
