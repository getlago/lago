# frozen_string_literal: true

require "rails_helper"

describe "Advance Charges Invoices Scenarios", transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax_rate) { 20 }
  let(:billable_metric) { create(:unique_count_billable_metric, organization:, code: "cards", recurring: true) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 49) }
  let(:external_subscription_id) { SecureRandom.uuid }
  let(:bm_amount) { 30.12 }

  def send_card_event!(item_id = SecureRandom.uuid)
    create_event({
      code: billable_metric.code,
      transaction_id: "tr_#{SecureRandom.hex(10)}",
      external_customer_id: customer.external_id,
      external_subscription_id:,
      properties: {item_id:}
    })
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: tax_rate)
    create(:standard_charge, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, billable_metric:, plan:, properties: {amount: bm_amount.to_s, grouped_by: nil})
  end

  context "when subscription is renewed" do
    it "generates an invoice with the correct charges" do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      subscription = customer.subscriptions.sole

      (1..5).each do |i|
        travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
          send_card_event! "card_#{i}"
          expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(i)
          expect(subscription.fees.charge.order(created_at: :desc).first.amount_cents).to eq ((bm_amount * (30 - 10 - (i - 1)) / 30) * 100).round
        end
      end

      expect(subscription.fees.charge.where(invoice_id: nil).count).to eq 5
      subscription.fees.charge.order(created_at: :asc).limit(3).update!(
        payment_status: :succeeded,
        succeeded_at: DateTime.new(2024, 6, 20, 0, 10)
      )
      travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
        perform_billing
        expect(customer.invoices.count).to eq(3)
        # The 2 pending fees are not attached to the invoice
        expect(subscription.fees.charge.where(invoice_id: nil, created_at: ..Time.current.beginning_of_month).count).to eq 2
        expect(subscription.fees.charge.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 1 # recurring fee

        advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).sole
        expect(advance_charges_invoice.fees_amount_cents).to eq(2008 + 1908 + 1807)
        expect(advance_charges_invoice.applied_taxes.first.taxable_base_amount_cents).to eq(2008 + 1908 + 1807)
      end

      travel_to(DateTime.new(2024, 7, 10, 10)) do
        # Mark fees created in June + recurring fee for July as payment succeeded
        Fee.where(invoice_id: nil).update!(
          payment_status: :succeeded,
          succeeded_at: Time.current
        )
      end

      travel_to(DateTime.new(2024, 8, 1, 0, 10)) do
        perform_billing
        expect(customer.invoices.count).to eq(5)

        advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).order(created_at: :desc).first
        expect(advance_charges_invoice.fees.count).to eq 3
        expect(advance_charges_invoice.fees.charge.where(created_at: ..DateTime.new(2024, 7, 1)).count).to eq 2
        expect(advance_charges_invoice.fees_amount_cents).to eq((5 * bm_amount * 100) + 1707 + 1606)

        expect(advance_charges_invoice.total_amount_cents).to eq 22047 # Invoices::ComputeAmountsFromFees would return 22048
        expect(advance_charges_invoice.taxes_amount_cents).to eq 3674 # Invoices::ComputeAmountsFromFees would return 3675
        expect(advance_charges_invoice.fees_amount_cents).to eq 18373

        expect(advance_charges_invoice.sub_total_excluding_taxes_amount_cents).to eq 18373 # == fees_amount_cents
        expect(advance_charges_invoice.applied_taxes.first.taxable_base_amount_cents).to eq(18373)
        expect(advance_charges_invoice.sub_total_including_taxes_amount_cents).to eq 22047 # == fees_amount_cents + taxes_amount_cents == total_amount_cents

        expect(advance_charges_invoice.coupons_amount_cents).to eq 0
        expect(advance_charges_invoice.credit_notes_amount_cents).to eq 0
        expect(advance_charges_invoice.prepaid_credit_amount_cents).to eq 0
        expect(advance_charges_invoice.progressive_billing_credit_amount_cents).to eq 0
      end
    end

    context "when regrouped fee is succeeded just before the billing run" do
      it "generates an invoice with the correct charges" do
        travel_to(DateTime.new(2024, 6, 5, 10)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code
            }
          )
          perform_billing
          expect(customer.invoices.count).to eq(1)
        end

        subscription = customer.subscriptions.sole

        travel_to(DateTime.new(2024, 7, 1, 0, 1)) do
          send_card_event! "card_1"
          expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
          expect(subscription.fees.charge.order(created_at: :desc).first.amount_cents).to eq (bm_amount * 100).round
          subscription.fees.charge.order(created_at: :asc).update!(
            payment_status: :succeeded,
            succeeded_at: DateTime.new(2024, 7, 1, 0, 1)
          )
        end
        travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
          perform_billing
          expect(customer.invoices.count).to eq(2)
          expect(customer.invoices.where(invoice_type: :advance_charges).count).to eq 0
        end

        travel_to(DateTime.new(2024, 8, 1, 0, 10)) do
          perform_billing
          expect(customer.invoices.count).to eq(4)

          advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).order(created_at: :desc).first
          expect(advance_charges_invoice.fees.count).to eq 1
          expect(advance_charges_invoice.fees.charge.where(created_at: ..DateTime.new(2024, 7, 1).end_of_day).count).to eq 1
          expect(advance_charges_invoice.fees_amount_cents).to eq(bm_amount * 100)

          expect(advance_charges_invoice.total_amount_cents).to eq 3614
          expect(advance_charges_invoice.taxes_amount_cents).to eq 602

          expect(advance_charges_invoice.sub_total_excluding_taxes_amount_cents).to eq 3012 # == fees_amount_cents
          expect(advance_charges_invoice.applied_taxes.first.taxable_base_amount_cents).to eq(3012)
          expect(advance_charges_invoice.sub_total_including_taxes_amount_cents).to eq 3614 # == fees_amount_cents + taxes_amount_cents == total_amount_cents

          expect(advance_charges_invoice.coupons_amount_cents).to eq 0
          expect(advance_charges_invoice.credit_notes_amount_cents).to eq 0
          expect(advance_charges_invoice.prepaid_credit_amount_cents).to eq 0
          expect(advance_charges_invoice.progressive_billing_credit_amount_cents).to eq 0
        end
      end
    end

    context "with multiple regrouped fees and the one that is succeeded just before the billing run" do
      it "generates an invoice with the correct charges" do
        travel_to(DateTime.new(2024, 6, 5, 10)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code
            }
          )
          perform_billing
          expect(customer.invoices.count).to eq(1)
        end

        subscription = customer.subscriptions.sole

        (1..4).each do |i|
          travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
            send_card_event! "card_#{i}"
            expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(i)
            expect(subscription.fees.charge.order(created_at: :desc).first.amount_cents).to eq ((bm_amount * (30 - 10 - (i - 1)) / 30) * 100).round
          end
        end

        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq 4
        subscription.fees.charge.order(created_at: :asc).limit(2).update!(
          payment_status: :succeeded,
          succeeded_at: DateTime.new(2024, 6, 20, 0, 10)
        )
        travel_to(DateTime.new(2024, 7, 1, 0, 1)) do
          send_card_event! "card_5"
          expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(5)
          expect(subscription.fees.charge.order(created_at: :desc).first.amount_cents).to eq (bm_amount * 100).round
        end
        subscription.fees.charge.order(created_at: :desc).limit(1).update!(
          payment_status: :succeeded,
          succeeded_at: DateTime.new(2024, 7, 1, 0, 1)
        )
        travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
          perform_billing
          expect(customer.invoices.count).to eq(3)
          # The 2 pending fees are not attached to the invoice
          expect(subscription.fees.charge.where(invoice_id: nil, created_at: ..Time.current.beginning_of_month).count).to eq 2
          expect(subscription.fees.charge.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 2 # recurring fee + new fee

          advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).sole
          expect(advance_charges_invoice.fees_amount_cents).to eq(2008 + 1908)
          expect(advance_charges_invoice.applied_taxes.first.taxable_base_amount_cents).to eq(2008 + 1908)
        end

        travel_to(DateTime.new(2024, 7, 10, 10)) do
          # Mark fees created in June + recurring fee for July as payment succeeded
          Fee.where(invoice_id: nil).update!(
            payment_status: :succeeded,
            succeeded_at: Time.current
          )
        end

        travel_to(DateTime.new(2024, 8, 1, 0, 10)) do
          perform_billing
          expect(customer.invoices.count).to eq(5)

          advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges).order(created_at: :desc).first
          expect(advance_charges_invoice.fees.count).to eq 4
          expect(advance_charges_invoice.fees.charge.where(created_at: ..DateTime.new(2024, 7, 1)).count).to eq 2
          expect(advance_charges_invoice.fees_amount_cents).to eq((4 * bm_amount * 100) + 1807 + 1707 + (bm_amount * 100))

          expect(advance_charges_invoice.total_amount_cents).to eq 22288 # Invoices::ComputeAmountsFromFees would return 22048
          expect(advance_charges_invoice.taxes_amount_cents).to eq 3714 # Invoices::ComputeAmountsFromFees would return 3675
          expect(advance_charges_invoice.fees_amount_cents).to eq 18574

          expect(advance_charges_invoice.sub_total_excluding_taxes_amount_cents).to eq 18574 # == fees_amount_cents
          expect(advance_charges_invoice.applied_taxes.first.taxable_base_amount_cents).to eq(18574)
          expect(advance_charges_invoice.sub_total_including_taxes_amount_cents).to eq 22288 # == fees_amount_cents + taxes_amount_cents == total_amount_cents

          expect(advance_charges_invoice.coupons_amount_cents).to eq 0
          expect(advance_charges_invoice.credit_notes_amount_cents).to eq 0
          expect(advance_charges_invoice.prepaid_credit_amount_cents).to eq 0
          expect(advance_charges_invoice.progressive_billing_credit_amount_cents).to eq 0
        end
      end
    end
  end

  context "when subscription is upgraded" do
    let(:plan_upgrade) { create(:plan, organization:, pay_in_advance: true, amount_cents: 259) }

    before do
      create(:standard_charge, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, billable_metric:, plan: plan_upgrade, properties: {amount: "60", grouped_by: nil})
    end

    it "generates an invoice with the correct charges" do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      subscription = customer.subscriptions.sole

      travel_to(DateTime.new(2024, 6, 10, 10)) do
        send_card_event! "card_1"
        send_card_event! "card_2"
        send_card_event! "card_3"
        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(3)
        subscription.fees.charge.where(invoice_id: nil).update!(
          payment_status: :succeeded,
          succeeded_at: Time.current
        )
      end

      upgraded_subscription = nil

      travel_to(DateTime.new(2024, 6, 15, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan_upgrade.code
          }
        )

        upgraded_subscription = customer.subscriptions.where.not(id: subscription.id).sole
        expect(customer.invoices.count).to eq(3)
        expect(upgraded_subscription.fees.charge.count).to eq 0
        advance_charges = customer.invoices.where(invoice_type: :advance_charges).sole
        expect(advance_charges.fees.count).to eq(3)
      end

      travel_to(DateTime.new(2024, 6, 20, 10)) do
        send_card_event! "card_4"
        expect(upgraded_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
        upgraded_subscription.fees.charge.where(invoice_id: nil).update!(
          payment_status: :succeeded,
          succeeded_at: Time.current
        )
      end

      travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
        perform_billing

        expect(customer.invoices.count).to eq(5)
        recurring_fee = upgraded_subscription.fees.charge.where(invoice_id: nil, created_at: Time.current.all_day).sole
        expect(recurring_fee.units).to eq 4

        advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges, created_at: Time.current.all_day).order(created_at: :desc).first
        expect(advance_charges_invoice.fees.count).to eq(1)
        expect(Fee.where(invoice_id: nil).excluding(recurring_fee).count).to eq 0
      end
    end
  end

  context "when subscription is downgraded" do
    let(:plan_downgrade) { create(:plan, organization:, pay_in_advance: true, amount_cents: 19) }

    before do
      create(:standard_charge, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, billable_metric:, plan: plan_downgrade, properties: {amount: "15", grouped_by: nil})
    end

    it "generates an invoice with the correct charges" do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      subscription = customer.subscriptions.sole

      travel_to(DateTime.new(2024, 6, 10, 10)) do
        send_card_event! "card_1"
        send_card_event! "card_2"
        send_card_event! "card_3"
        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(3)
        subscription.fees.charge.where(invoice_id: nil).update!(
          payment_status: :succeeded,
          succeeded_at: Time.current
        )
      end

      downgraded_subscription = nil

      travel_to(DateTime.new(2024, 6, 15, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan_downgrade.code
          }
        )
        perform_billing

        downgraded_subscription = customer.subscriptions.where.not(id: subscription.id).sole
        expect(customer.invoices.count).to eq(1)
        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq 3
        expect(downgraded_subscription.fees.charge.where(invoice_id: nil).count).to eq 0
        expect(subscription).to be_active
        expect(downgraded_subscription).to be_pending
      end

      travel_to(DateTime.new(2024, 6, 20, 10)) do
        send_card_event! "card_4"
        expect(downgraded_subscription.fees.charge.where(invoice_id: nil).count).to eq(0)
        expect(subscription.fees.charge.where(invoice_id: nil).count).to eq 4
        subscription.fees.charge.where(invoice_id: nil).update!(
          payment_status: :succeeded,
          succeeded_at: Time.current
        )
      end

      travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
        perform_billing

        expect(customer.invoices.count).to eq(3)
        recurring_fee = subscription.fees.charge.where(invoice_id: nil, created_at: Time.current.all_day).sole
        expect(recurring_fee.units).to eq 4

        recurring_fee = downgraded_subscription.fees.charge.where(invoice_id: nil, created_at: Time.current.all_day)
        expect(recurring_fee.count).to eq 0

        advance_charges_invoice = customer.invoices.where(invoice_type: :advance_charges, created_at: Time.current.all_day).order(created_at: :desc).first
        expect(advance_charges_invoice.fees.count).to eq(4)
        expect(Fee.where(invoice_id: nil).excluding(recurring_fee).count).to eq 1
      end
    end
  end
end
