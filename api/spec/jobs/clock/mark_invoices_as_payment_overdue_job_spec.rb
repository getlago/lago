# frozen_string_literal: true

require "rails_helper"

describe Clock::MarkInvoicesAsPaymentOverdueJob, job: true do
  subject { described_class }

  describe ".perform" do
    let!(:overdue_invoice_1) { create(:invoice, payment_due_date: 1.day.ago) }
    let!(:overdue_invoice_2) { create(:invoice, payment_due_date: 2.days.ago) }

    it "marks expected invoices as payment overdue" do
      create(:invoice, :draft, payment_due_date: 1.day.ago)
      create(:invoice, payment_status: :succeeded, payment_due_date: 1.day.ago)
      create(:invoice, payment_due_date: 1.day.ago, payment_dispute_lost_at: 1.day.ago)
      create(:invoice, payment_due_date: nil)
      create(:invoice, payment_due_date: 1.day.from_now)

      expect do
        described_class.perform_now
      end.to have_enqueued_job(Invoices::Payments::MarkOverdueJob).with(invoice: overdue_invoice_1)
        .and have_enqueued_job(Invoices::Payments::MarkOverdueJob).with(invoice: overdue_invoice_2)
    end
  end

  describe "index usage" do
    # Force PostgreSQL to use indexes even on a tiny test dataset so we can
    # verify the planner CAN use them for the query patterns the job produces.
    around do |example|
      ActiveRecord::Base.connection.execute("SET enable_seqscan = off")
      example.run
    ensure
      ActiveRecord::Base.connection.execute("SET enable_seqscan = on")
    end

    it "uses the partial index on payment_due_date for the overdue invoice lookup" do
      create(:invoice, payment_due_date: 1.day.ago)

      plan = Invoice
        .finalized
        .not_payment_succeeded
        .where(payment_overdue: false)
        .where(payment_dispute_lost_at: nil)
        .where(payment_due_date: ...Time.current)
        .order(:payment_due_date, :id)
        .limit(1000)
        .explain
        .inspect

      expect(plan).to include("index_invoices_on_payment_due_date")
    end
  end
end
