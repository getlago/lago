# frozen_string_literal: true

require "rails_helper"

describe "Void Invoice Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 1000, pay_in_advance: true) }

  before do
    tax
    stub_pdf_generation
  end

  context "when voiding a basic invoice" do
    it "marks the invoice as voided" do
      travel_to(DateTime.new(2023, 1, 1)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_#{customer.external_id}",
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first
      invoice = subscription.invoices.first
      expect(invoice).to be_present
      expect(invoice).to be_finalized

      void_invoice(invoice, {generate_credit_note: true, credit_amount: 1200, refund_amount: 0})

      invoice.reload
      expect(invoice).to be_voided
      expect(invoice.voided_at).to be_present
      expect(invoice.credit_notes.count).to eq(1)

      credit_note = invoice.credit_notes.first
      expect(credit_note).to be_present
      expect(credit_note.credit_status).to eq("available")
      expect(credit_note.credit_amount_cents).to eq(1200)
      expect(credit_note.refund_amount_cents).to eq(0)
      expect(credit_note.total_amount_cents).to eq(1200)
      expect(credit_note.status).to eq("finalized")
    end
  end

  context "when voiding a fully paid invoice" do
    it "voids the invoice and creates a credit note with refund" do
      # Create a subscription
      travel_to(DateTime.new(2023, 1, 1)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_paid_#{customer.external_id}",
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first
      invoice = subscription.invoices.first
      expect(invoice).to be_present
      expect(invoice).to be_finalized

      Payments::ManualCreateService.call(
        organization:,
        params: {invoice_id: invoice.id, amount_cents: invoice.total_amount_cents, reference: "payment_ref_1"}
      )

      void_invoice(invoice, {generate_credit_note: true, credit_amount: 0, refund_amount: invoice.total_amount_cents})

      invoice.reload
      expect(invoice.payment_status).to eq("succeeded")
      expect(invoice).to be_voided
      expect(invoice.voided_at).to be_present
      expect(invoice.credit_notes.count).to eq(1)

      credit_note = invoice.credit_notes.first
      expect(credit_note).to be_present
      expect(credit_note.credit_amount_cents).to eq(0)
      expect(credit_note.refund_amount_cents).to eq(invoice.total_amount_cents)
      expect(credit_note.total_amount_cents).to eq(invoice.total_amount_cents)
      expect(credit_note.status).to eq("finalized")
    end
  end

  context "when voiding an invoice with partial credit and refund" do
    it "creates a partial credit note and a voided credit note for the remaining amount" do
      # Create a subscription
      travel_to(DateTime.new(2023, 1, 1)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_partial_#{customer.external_id}",
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first
      invoice = subscription.invoices.first
      expect(invoice).to be_present
      expect(invoice).to be_finalized

      Payments::ManualCreateService.call(
        organization:,
        params: {invoice_id: invoice.id, amount_cents: 300, reference: "payment_ref_partial"}
      )

      invoice.reload
      expect(invoice.payment_status).to eq("pending")

      total_amount = invoice.total_amount_cents
      partial_amount = total_amount / 2
      credit_amount = partial_amount - 300
      refund_amount = 300

      void_invoice(invoice, {generate_credit_note: true, credit_amount: credit_amount, refund_amount: refund_amount})

      invoice.reload
      expect(invoice).to be_voided
      expect(invoice.voided_at).to be_present
      expect(invoice.credit_notes.count).to eq(2)

      first_credit_note = invoice.credit_notes.order(created_at: :asc).first
      expect(first_credit_note).to be_present
      expect(first_credit_note.credit_amount_cents).to eq(credit_amount)
      expect(first_credit_note.refund_amount_cents).to eq(refund_amount)
      expect(first_credit_note.total_amount_cents).to eq(partial_amount)
      expect(first_credit_note.status).to eq("finalized")
      expect(first_credit_note.credit_status).to eq("available")
      expect(first_credit_note).not_to be_voided

      second_credit_note = invoice.credit_notes.order(created_at: :asc).last
      expect(second_credit_note).to be_present
      expect(second_credit_note.total_amount_cents).to eq(total_amount - partial_amount)
      expect(second_credit_note.refund_amount_cents).to eq(0)
      expect(second_credit_note.status).to eq("finalized")
      expect(second_credit_note.credit_status).to eq("voided")
      expect(second_credit_note).to be_voided
    end
  end
end
