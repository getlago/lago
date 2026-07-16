# frozen_string_literal: true

require "rails_helper"

# End-to-end scenario: regenerating a voided advance_charges invoice.
#
# Flow:
#   1. Create a plan with a pay-in-advance, non-invoiceable charge (regroup_paid_fees: invoice)
#   2. Subscribe a customer and ingest events that produce pay-in-advance fees
#   3. Run billing to group those fees into an advance_charges invoice
#   4. Void the invoice
#   5. Regenerate it with adjusted fee params
#
# This exercises three fixes:
#   - the idx_pay_in_advance_duplication_guard_charge unique index now allows
#     duplicate pay_in_advance_event_transaction_id on regenerated fees
#   - create_invoice_subscriptions now runs for any voided invoice that had them,
#     not only subscription-type invoices
#   - AdjustedFees::CreateService only calls RefreshDraftService for draft
#     subscription invoices, avoiding forbidden_failure! on advance_charges
#
describe "Regenerate Voided Advance Charges Invoice Scenarios", :with_pdf_generation_stub, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax_rate) { 20 }
  let(:billable_metric) { create(:unique_count_billable_metric, organization:, code: "cards", recurring: true) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 49) }
  let(:external_subscription_id) { SecureRandom.uuid }

  def send_card_event!(item_id = SecureRandom.uuid)
    create_event({
      code: billable_metric.code,
      transaction_id: "tr_#{SecureRandom.hex(10)}",
      external_customer_id: customer.external_id,
      external_subscription_id:,
      properties: {item_id:}
    })
  end

  def create_advance_charges_invoice
    travel_to(DateTime.new(2024, 6, 5, 10)) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: external_subscription_id,
          plan_code: plan.code
        }
      )
      perform_billing
    end

    subscription = customer.subscriptions.sole

    (1..3).each do |i|
      travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
        send_card_event! "card_#{i}"
      end
    end

    subscription.fees.charge.where(invoice_id: nil).update!(
      payment_status: :succeeded,
      succeeded_at: DateTime.new(2024, 6, 20, 0, 10)
    )

    travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
      perform_billing
    end

    invoice = customer.invoices.where(invoice_type: :advance_charges).sole
    expect(invoice).to be_finalized
    expect(invoice.fees.count).to eq(3)
    expect(invoice.invoice_subscriptions).not_to be_empty

    invoice
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: tax_rate)
    create(
      :standard_charge,
      regroup_paid_fees: "invoice",
      pay_in_advance: true,
      invoiceable: false,
      prorated: true,
      billable_metric:,
      plan:,
      properties: {amount: "30.12", grouped_by: nil}
    )
  end

  context "when regenerating with fee id (primary UI path)" do
    it "regenerates a voided advance_charges invoice with adjusted fees" do
      advance_charges_invoice = create_advance_charges_invoice
      subscription = customer.subscriptions.sole
      original_fee = advance_charges_invoice.fees.first

      void_invoice(advance_charges_invoice)
      expect(advance_charges_invoice).to be_voided

      fees_params = [
        {
          id: original_fee.id,
          subscription_id: subscription.id,
          units: 5,
          unit_amount_cents: 20.0
        }
      ]

      result = Invoices::RegenerateFromVoidedService.call(
        voided_invoice: advance_charges_invoice,
        fees_params:
      )

      expect(result).to be_success

      regenerated_invoice = result.invoice
      expect(regenerated_invoice.invoice_type).to eq("advance_charges")
      expect(regenerated_invoice).to be_finalized
      expect(regenerated_invoice.invoice_subscriptions).not_to be_empty

      regenerated_fee = regenerated_invoice.fees.first
      expect(regenerated_fee.pay_in_advance_event_transaction_id).to eq(original_fee.pay_in_advance_event_transaction_id)
      expect(regenerated_fee.units).to eq(5)
      expect(regenerated_fee.unit_amount_cents).to eq(2000)
      expect(regenerated_fee.amount_cents).to eq(10_000)

      # Original fee on the voided invoice is untouched
      expect(original_fee.reload.pay_in_advance_event_transaction_id).to be_present
    end
  end

  context "when multiple void/regenerate cycles occur" do
    it "preserves pay_in_advance_event_transaction_id across the chain" do
      advance_charges_invoice = create_advance_charges_invoice
      subscription = customer.subscriptions.sole
      original_fee = advance_charges_invoice.fees.first
      original_transaction_id = original_fee.pay_in_advance_event_transaction_id

      # First cycle: void → regenerate
      void_invoice(advance_charges_invoice)

      first_result = Invoices::RegenerateFromVoidedService.call(
        voided_invoice: advance_charges_invoice,
        fees_params: [{id: original_fee.id, subscription_id: subscription.id, units: 5, unit_amount_cents: 20.0}]
      )
      expect(first_result).to be_success

      first_regenerated_invoice = first_result.invoice
      first_regenerated_fee = first_regenerated_invoice.fees.first
      expect(first_regenerated_fee.pay_in_advance_event_transaction_id).to eq(original_transaction_id)

      # Second cycle: void the regenerated invoice → regenerate again
      void_invoice(first_regenerated_invoice)
      expect(first_regenerated_invoice).to be_voided

      second_result = Invoices::RegenerateFromVoidedService.call(
        voided_invoice: first_regenerated_invoice,
        fees_params: [{id: first_regenerated_fee.id, subscription_id: subscription.id, units: 8, unit_amount_cents: 15.0}]
      )
      expect(second_result).to be_success

      second_regenerated_invoice = second_result.invoice
      second_regenerated_fee = second_regenerated_invoice.fees.first

      # pay_in_advance_event_transaction_id is preserved across all regenerations
      expect(second_regenerated_fee.pay_in_advance_event_transaction_id).to eq(original_transaction_id)
      expect(second_regenerated_fee.units).to eq(8)
      expect(second_regenerated_fee.unit_amount_cents).to eq(1500)
    end
  end

  context "when regenerating without fee id (charge-based path)" do
    it "creates fees via invoice_subscriptions and adjusts them" do
      advance_charges_invoice = create_advance_charges_invoice
      subscription = customer.subscriptions.sole
      charge = subscription.plan.charges.first

      void_invoice(advance_charges_invoice)
      expect(advance_charges_invoice).to be_voided

      fees_params = [
        {
          subscription_id: subscription.id,
          charge_id: charge.id,
          units: 5,
          unit_amount_cents: 20.0
        }
      ]

      result = Invoices::RegenerateFromVoidedService.call(
        voided_invoice: advance_charges_invoice,
        fees_params:
      )

      expect(result).to be_success

      regenerated_invoice = result.invoice
      expect(regenerated_invoice.invoice_type).to eq("advance_charges")
      expect(regenerated_invoice).to be_finalized
      expect(regenerated_invoice.invoice_subscriptions).not_to be_empty
      expect(regenerated_invoice.fees.count).to be >= 1
    end
  end
end
