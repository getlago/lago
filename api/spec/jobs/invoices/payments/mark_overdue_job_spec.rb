# frozen_string_literal: true

require "rails_helper"

describe Invoices::Payments::MarkOverdueJob, job: true do
  subject { described_class.new }

  describe ".perform" do
    let(:overdue_invoice) { create(:invoice, payment_due_date: 1.day.ago) }

    before do
      overdue_invoice
    end

    it "marks expected invoices as payment overdue" do
      described_class.perform_now(invoice: overdue_invoice)
      expect(Invoice.payment_overdue).to eq([overdue_invoice])
    end

    it "enqueues a SendWebhookJob" do
      expect do
        described_class.perform_now(invoice: overdue_invoice)
      end.to have_enqueued_job(SendWebhookJob).with("invoice.payment_overdue", overdue_invoice)
    end

    context "when invoice is draft" do
      let(:invoice) { create(:invoice, :draft, payment_due_date: 1.day.ago) }

      it "returns a failure" do
        result = described_class.perform_now(invoice: invoice)
        expect(result).not_to be_success
        expect(result.error.message).to eq("invoice_not_finalized")
      end
    end

    context "when invoice is succeeded" do
      let(:invoice) { create(:invoice, payment_status: :succeeded, payment_due_date: 1.day.ago) }

      it "returns a failure" do
        result = described_class.perform_now(invoice: invoice)
        expect(result).not_to be_success
        expect(result.error.message).to eq("invoice_payment_already_succeeded")
      end
    end

    context "when invoice is dispute lost" do
      let(:invoice) { create(:invoice, payment_due_date: 1.day.ago, payment_dispute_lost_at: 1.day.ago) }

      it "returns a failure" do
        result = described_class.perform_now(invoice: invoice)
        expect(result).not_to be_success
        expect(result.error.message).to eq("invoice_dispute_lost")
      end
    end

    context "when invoice is nil" do
      it "returns a failure" do
        result = described_class.perform_now(invoice: nil)
        expect(result).not_to be_success
        expect(result.error.message).to eq("invoice_not_found")
      end
    end

    context "when invoice is future" do
      let(:invoice) { create(:invoice, payment_due_date: 1.day.from_now) }

      it "returns a failure" do
        result = described_class.perform_now(invoice: invoice)
        expect(result).not_to be_success
        expect(result.error.message).to eq("invoice_due_date_in_future")
      end
    end
  end
end
