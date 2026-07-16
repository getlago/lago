# frozen_string_literal: true

require "rails_helper"

describe "Advance Charges Invoices Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax_rate_1) { 9.3 }
  let(:tax_rate_2) { 12 }
  let(:billable_metric_cards) { create(:unique_count_billable_metric, organization:, code: "cards", recurring: true) }
  let(:billable_metric_transfer) { create(:sum_billable_metric, organization:, code: "transfer", recurring: false) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 49) }
  let(:external_subscription_id) { "sub_" + SecureRandom.uuid }

  def send_card_event!(item_id = SecureRandom.uuid)
    send_event!(code: billable_metric_cards.code, item_id:)
  end

  def send_card_transfer!(item_id = SecureRandom.uuid)
    send_event!(code: billable_metric_transfer.code, item_id:)
  end

  def send_event!(code:, item_id:)
    create_event({
      code:,
      transaction_id: "tr_#{SecureRandom.hex(10)}",
      external_customer_id: customer.external_id,
      external_subscription_id:,
      properties: {item_id:}
    })
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: tax_rate_1, code: "tax-1", description: "VAT 1", name: "VAT")
    create(:tax, :applied_to_billing_entity, organization:, rate: tax_rate_2, code: "tax-2", description: "VAT 2", name: "bug VAT")
    create(:standard_charge, billable_metric: billable_metric_cards, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, plan:, properties: {amount: "30", grouped_by: nil})
    create(:standard_charge, billable_metric: billable_metric_transfer, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: false, plan:, properties: {amount: "1", grouped_by: nil})
  end

  context "when subscription is renewed" do
    it "generates an invoice with the correct taxes" do
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
        travel_to(DateTime.new(2024, 6, 10 + i, 1)) do
          send_card_event! "card_#{i}"
          expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(i)
          created_fee = subscription.fees.charge.order(created_at: :desc).first

          expect(created_fee.amount_cents).to eq((21 - i) * 100)
          expect(created_fee.taxes_rate).to eq(tax_rate_1 + tax_rate_2)
          expect(created_fee.applied_taxes.count).to eq(2)
          expect(created_fee.applied_taxes.find { it.tax_code == "tax-1" }.amount_cents).to eq (created_fee.amount_cents * tax_rate_1 / 100).round
          expect(created_fee.applied_taxes.find { it.tax_code == "tax-2" }.amount_cents).to eq (created_fee.amount_cents * tax_rate_2 / 100).round
        end
      end

      travel_to(DateTime.new(2024, 6, 22, 1)) do
        send_card_event! "transfer_1"
        send_card_event! "transfer_2"
        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(5)

        fees = subscription.fees.charge.order(created_at: :desc).first(2)
        fees.each do |fee|
          expect(fee.applied_taxes.count).to eq(2)
        end
      end

      expect(subscription.fees.charge.where(invoice_id: nil).count).to eq 5
      subscription.fees.charge.order(created_at: :asc).update!(
        payment_status: :succeeded,
        succeeded_at: DateTime.new(2024, 6, 24)
      )

      travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
        perform_billing
        expect(customer.invoices.count).to eq(3) # 2 subscription invoices, 1 advance_charges invoice

        advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).sole
        expect(advance_charges_invoice.applied_taxes.count).to eq(2)

        total_tax_1 = 0
        total_tax_2 = 0
        advance_charges_invoice.fees.flat_map(&:applied_taxes).each do |applied_tax|
          if applied_tax.tax_code == "tax-1"
            total_tax_1 += applied_tax.amount_cents
          elsif applied_tax.tax_code == "tax-2"
            total_tax_2 += applied_tax.amount_cents
          end
        end
        expect(advance_charges_invoice.applied_taxes.find { it.tax_code == "tax-1" }.amount_cents).to eq total_tax_1
        expect(advance_charges_invoice.applied_taxes.find { it.tax_code == "tax-2" }.amount_cents).to eq total_tax_2
      end
    end
  end
end
