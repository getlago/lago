# frozen_string_literal: true

require "rails_helper"

describe Clock::RefreshDraftInvoicesJob, job: true do
  subject { described_class }

  describe ".perform" do
    let(:invoice) { create(:invoice, :draft) }
    let(:subscription) { create(:subscription) }
    let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

    before do
      invoice_subscription
      allow(Invoices::RefreshDraftService).to receive(:call)
    end

    context "when not ready to be refreshed" do
      it "does not call the refresh service" do
        described_class.perform_now
        expect(Invoices::RefreshDraftJob).not_to have_been_enqueued.with(invoice:)
      end
    end

    context "when invoice is related only to terminated subscriptions" do
      let(:invoice) { create(:invoice, :draft, ready_to_be_refreshed: true) }
      let(:subscription) { create(:subscription, :terminated) }

      it "does not call the refresh service" do
        described_class.perform_now
        expect(Invoices::RefreshDraftJob).not_to have_been_enqueued.with(invoice:)
      end
    end

    context "when ready to be refreshed" do
      let(:invoice) { create(:invoice, :draft, ready_to_be_refreshed: true) }

      it "calls the refresh service" do
        described_class.perform_now
        expect(Invoices::RefreshDraftJob).to have_been_enqueued.with(invoice:)
      end
    end
  end
end
