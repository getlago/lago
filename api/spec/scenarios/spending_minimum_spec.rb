# frozen_string_literal: true

require "rails_helper"

describe "Spending Minimum Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 5000) }
  let(:metric) { create(:billable_metric, organization:) }

  before { tax }

  context "when invoice grace period" do
    let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }

    it "creates expected credit note and invoice" do
      ### 8 Jan: Create subscription
      travel_to(DateTime.new(2023, 1, 8, 8)) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        }.to change(Invoice, :count).by(1)

        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          properties: {amount: "8"},
          min_amount_cents: 1000
        )
      end

      subscription = customer.subscriptions.find_by(external_id: customer.external_id)
      sub_invoice = subscription.invoices.first
      expect(sub_invoice.total_amount_cents).to eq(4645) # 60 / 31 * 24

      travel_to(DateTime.new(2023, 2, 1, 6)) do
        perform_billing
      end

      last_invoice = subscription.invoices.order(created_at: :desc).first

      ### 25 Feb: Create event and Terminate subscription
      travel_to(DateTime.new(2023, 2, 25, 6)) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id
          }
        )

        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(2).to(3)

        term_invoice = subscription.invoices.order(created_at: :desc).first
        expect(term_invoice).to be_draft

        expect(term_invoice.fees.count).to eq(2)
        usage_fee = term_invoice.fees.where(true_up_parent_fee_id: nil).first
        true_up_fee = usage_fee.true_up_fee

        expect(usage_fee).to have_attributes(
          amount_cents: 800,
          taxes_amount_cents: 160,
          units: 1
        )

        # True up fee is pro-rated for 25/28 days.
        expect(true_up_fee).to have_attributes(
          amount_cents: 93, # 1000 / 28.0 * 25 - 800
          taxes_amount_cents: 19,
          units: 1
        )

        expect(term_invoice).to have_attributes(
          fees_amount_cents: 893,
          taxes_amount_cents: 179,
          credit_notes_amount_cents: 0,
          total_amount_cents: 1072
        )

        # Refresh pay in advance invoice
        refresh_invoice(last_invoice)

        credit_note = last_invoice.credit_notes.first
        expect(credit_note).to be_draft
        expect(credit_note.reload).to have_attributes(
          sub_total_excluding_taxes_amount_cents: 536,
          credit_amount_cents: 643,
          taxes_amount_cents: 107,
          total_amount_cents: 643
        )

        # Refresh termination invoice
        expect {
          refresh_invoice(term_invoice)
        }.not_to change { term_invoice.reload.total_amount_cents }

        # Finalize pay in advance invoice
        expect {
          finalize_invoice(last_invoice)
        }.to change { last_invoice.reload.status }.from("draft").to("finalized")
          .and change { credit_note.reload.status }.from("draft").to("finalized")

        # Finalize termination invoice
        expect {
          finalize_invoice(term_invoice)
        }.to change { term_invoice.reload.status }.from("draft").to("finalized")

        credit_note = last_invoice.credit_notes.first
        expect(credit_note.total_amount_cents).to eq(643) # 60.0 / 28 * 3

        expect(term_invoice).to have_attributes(
          fees_amount_cents: 893,
          taxes_amount_cents: 179,
          credit_notes_amount_cents: 643,
          total_amount_cents: 429 # 893 + 179 - 643
        )
      end
    end
  end

  context "when filters" do
    let(:billable_metric_filter) do
      create(:billable_metric_filter, billable_metric: metric, key: "region", values: %w[europe usa])
    end

    it "creates expected credit note and invoice" do
      ### 8 Jan: Create subscription
      travel_to(DateTime.new(2023, 1, 8)) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        }.to change(Invoice, :count).by(1)

        charge = create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          properties: {amount: "0"},
          min_amount_cents: 10_000
        )

        europe_filter = create(:charge_filter, charge:, properties: {amount: "20"})
        create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter:, values: ["europe"])

        usa_filter = create(:charge_filter, charge:, properties: {amount: "50"})
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter:, values: ["usa"])
      end

      subscription = customer.subscriptions.find_by(external_id: customer.external_id)
      sub_invoice = subscription.invoices.first
      expect(sub_invoice.total_amount_cents).to eq(4645) # 60 / 31 * 24

      travel_to(DateTime.new(2023, 2, 1, 6)) do
        perform_billing
      end

      ### 25 Feb: Create event and Terminate subscription
      travel_to(DateTime.new(2023, 2, 25, 8)) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {
              region: "usa"
            }
          }
        )

        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {
              region: "europe"
            }
          }
        )

        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(2).to(3)

        term_invoice = subscription.invoices.order(created_at: :desc).first
        expect(term_invoice).to be_finalized
        expect(term_invoice.fees.count).to eq(4)

        usage_fees = term_invoice.fees.where(true_up_parent_fee_id: nil)
        expect(usage_fees.count).to eq(3)
        expect(usage_fees.pluck(:amount_cents)).to contain_exactly(0, 2000, 5000)

        true_up_fee = term_invoice.fees.where.not(true_up_parent_fee_id: nil).first
        # True up fee is pro-rated for 25/28 days.
        expect(true_up_fee).to have_attributes(
          amount_cents: 1929, # 10000 / 28.0 * 25 - 2000 - 5000
          taxes_amount_cents: 386,
          units: 1
        )

        expect(term_invoice).to have_attributes(
          fees_amount_cents: 8929, # 1929 + 2000 + 5000
          taxes_amount_cents: 1786,
          credit_notes_amount_cents: 643,
          total_amount_cents: 10_072
        )
      end
    end
  end
end
