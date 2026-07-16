# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizeOpenCreditService do
  let(:service) { described_class.new(invoice:) }

  let(:organization) { create(:organization, email_settings: Organization::EMAIL_SETTINGS) }
  let(:invoice) { create(:invoice, organization:, invoice_type: "credit", status: :open, payment_due_date: 1.week.ago.to_date) }

  before do
    if invoice
      allow(invoice).to receive(:should_sync_invoice?).and_return(true)
    end
  end

  describe ".call" do
    it "updates invoice status and enqueues necessary jobs" do
      result = described_class.call(invoice:)

      expect(result.invoice.status).to eq("finalized")
      expect(result.invoice.issuing_date).to be_today
      expect(result.invoice.payment_due_date).to be_today

      expect(SendWebhookJob).to have_been_enqueued.with("invoice.paid_credit_added", result.invoice)
      expect(Invoices::GenerateDocumentsJob).to have_been_enqueued.with(invoice: result.invoice, notify: false)
      expect(Integrations::Aggregator::Invoices::CreateJob).to have_been_enqueued.with(invoice: result.invoice)
      expect(SegmentTrackJob).to have_been_enqueued.with(membership_id: anything, event: "invoice_created", properties: {
        organization_id: result.invoice.organization.id,
        invoice_id: result.invoice.id,
        invoice_type: result.invoice.invoice_type
      })
      expect(Utils::ActivityLog).to have_produced("invoice.paid_credit_added").with(invoice)
    end

    context "when invoice is already finalized" do
      let(:invoice) { create(:invoice, organization:, invoice_type: "credit", status: :finalized) }

      it "does not update invoice status" do
        result = service.call

        expect(result.invoice.status).to eq("finalized")

        expect(SendWebhookJob).not_to have_been_enqueued
        expect(Invoices::GenerateDocumentsJob).not_to have_been_enqueued
        expect(Integrations::Aggregator::Invoices::CreateJob).not_to have_been_enqueued
        expect(SegmentTrackJob).not_to have_been_enqueued
      end
    end

    context "when invoice is not found" do
      let(:invoice) { nil }

      it "returns not found failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end
  end
end
