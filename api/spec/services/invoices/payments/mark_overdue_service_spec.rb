# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::MarkOverdueService do
  let(:result) { described_class.call(invoice:) }

  let(:invoice) do
    create(:invoice,
      payment_due_date: invoice_due_date,
      status: invoice_status,
      payment_status: invoice_payment_status,
      payment_dispute_lost_at: invoice_dispute_lost_at)
  end
  let(:invoice_payment_status) { :pending }
  let(:invoice_due_date) { 1.day.ago }
  let(:invoice_status) { :finalized }
  let(:invoice_dispute_lost_at) { nil }

  describe "#call" do
    it "mark the invoice as payment_overdue" do
      expect(result.invoice.payment_overdue).to be_truthy
    end

    it "sends invoice.payment_overdue hook" do
      invoice = result.invoice

      expect(SendWebhookJob).to have_been_enqueued.with("invoice.payment_overdue", invoice)
    end

    it "produces an activity log" do
      invoice = result.invoice

      expect(Utils::ActivityLog).to have_produced("invoice.payment_overdue").after_commit.with(invoice)
    end

    context "when invoice is nil" do
      let(:invoice) { nil }

      it "returns a not found error" do
        expect(result.success?).to be(false)
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when invoice is not finalized" do
      let(:invoice_status) { :draft }

      it "returns not allowed failure" do
        expect(result.success?).to be(false)
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoice_not_finalized")
      end
    end

    context "when invoice payment succeeded" do
      let(:invoice_payment_status) { :succeeded }

      it "returns not allowed failure" do
        expect(result.success?).to be(false)
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoice_payment_already_succeeded")
      end
    end

    context "when invoice due date is in future" do
      let(:invoice_due_date) { 5.days.from_now }

      it "returns not allowed failure" do
        expect(result.success?).to be(false)
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoice_due_date_in_future")
      end
    end

    context "when invoice is disputed and lost" do
      let(:invoice_dispute_lost_at) { 1.day.ago }

      it "returns not allowed failure" do
        expect(result.success?).to be(false)
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoice_dispute_lost")
      end
    end
  end
end
