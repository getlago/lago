# frozen_string_literal: true

require "rails_helper"

describe Clock::FinalizeInvoicesJob, job: true do
  subject { described_class }

  describe ".perform" do
    let(:customer) { create(:customer, invoice_grace_period: 3) }
    let(:draft_invoice) do
      create(
        :invoice,
        status: :draft,
        issuing_date: DateTime.parse("23 Jun 2022").to_date,
        expected_finalization_date: DateTime.parse("23 Jun 2022").to_date,
        customer:,
        organization: customer.organization
      )
    end
    let(:finalized_invoice) do
      create(
        :invoice,
        status: :finalized,
        issuing_date: DateTime.parse("23 Jun 2022").to_date,
        expected_finalization_date: DateTime.parse("23 Jun 2022").to_date,
        customer:,
        organization: customer.organization
      )
    end

    before do
      draft_invoice
      finalized_invoice
      allow(Invoices::RefreshDraftAndFinalizeService).to receive(:call)
    end

    context "when during the grace period" do
      it "does not call the finalize service" do
        current_date = DateTime.parse("22 Jun 2022")

        travel_to(current_date) do
          described_class.perform_now
          expect(Invoices::FinalizeJob).not_to have_been_enqueued.with(draft_invoice)
          expect(Invoices::FinalizeJob).not_to have_been_enqueued.with(finalized_invoice)
        end
      end
    end

    context "when after the grace period" do
      it "calls the finalize service" do
        current_date = DateTime.parse("24 Jun 2022")

        travel_to(current_date) do
          described_class.perform_now
          expect(Invoices::FinalizeJob).to have_been_enqueued.with(draft_invoice)
        end
      end
    end
  end
end
