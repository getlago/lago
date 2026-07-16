# frozen_string_literal: true

require "rails_helper"

describe "Terminate Pay in Advance Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 5000) }
  let(:metric) { create(:billable_metric, organization:) }

  before { tax }

  it "creates expected credit note and invoice" do
    ### 8 Feb: Create and terminate subscription
    feb8 = DateTime.new(2023, 2, 8)

    travel_to(feb8) do
      expect {
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      }.to change(Invoice, :count).by(1)

      subscription = customer.subscriptions.find_by(external_id: customer.external_id)
      sub_invoice = subscription.invoices.first
      expect(sub_invoice.total_amount_cents).to eq(4500) # 60 / 28 * 21

      expect {
        terminate_subscription(subscription)
      }.to change { subscription.reload.status }.from("active").to("terminated")
        .and change { subscription.invoices.count }.from(1).to(2)
        .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

      term_invoice = subscription.invoices.order(sequential_id: :desc).first
      expect(term_invoice.total_amount_cents).to eq(0)

      credit_note = sub_invoice.credit_notes.first
      expect(credit_note).to have_attributes(
        sub_total_excluding_taxes_amount_cents: 3571,
        taxes_amount_cents: 714,
        credit_amount_cents: 4285,
        total_amount_cents: 4285 # 60.0 / 28 * 20
      )
    end
  end

  context "when customer is in UTC+ timezone" do
    let(:customer) { create(:customer, organization:, timezone: "Asia/Tokyo") }

    it "creates expected credit note and invoice" do
      ### 8 Feb: Create and terminate subscription
      feb8 = DateTime.new(2023, 2, 8)

      travel_to(feb8) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        }.to change(Invoice, :count).by(1)

        subscription = customer.subscriptions.find_by(external_id: customer.external_id)
        sub_invoice = subscription.invoices.first
        expect(sub_invoice.total_amount_cents).to eq(4500) # 60 / 28 * 21

        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(1).to(2)
          .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

        term_invoice = subscription.invoices.order(sequential_id: :desc).first
        expect(term_invoice.total_amount_cents).to eq(0)

        credit_note = sub_invoice.credit_notes.first
        expect(credit_note).to have_attributes(
          sub_total_excluding_taxes_amount_cents: 3571,
          taxes_amount_cents: 714,
          credit_amount_cents: 4285,
          total_amount_cents: 4285 # 60.0 / 28 * 20
        )
      end
    end
  end

  context "when customer is in UTC- timezone" do
    let(:customer) { create(:customer, organization:, timezone: "America/Los_Angeles") }

    it "creates expected credit note and invoice" do
      ### 8 Feb: Create and terminate subscription
      feb8 = DateTime.new(2023, 2, 8)

      travel_to(feb8) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        }.to change(Invoice, :count).by(1)

        subscription = customer.subscriptions.find_by(external_id: customer.external_id)
        sub_invoice = subscription.invoices.first
        expect(sub_invoice.total_amount_cents).to eq(4715) # 60 / 28 * 22

        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(1).to(2)
          .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

        term_invoice = subscription.invoices.order(sequential_id: :desc).first
        expect(term_invoice.total_amount_cents).to eq(0)

        credit_note = sub_invoice.credit_notes.first
        expect(credit_note.total_amount_cents).to eq(4500) # 3750 + (3750 * 20 / 100)
      end
    end
  end

  context "when subscription billing is anniversary" do
    it "creates expected credit note and invoice" do
      ### 8 Feb: Create and terminate subscription
      feb8 = DateTime.new(2023, 2, 8)

      travel_to(feb8) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary"
            }
          )
        }.to change(Invoice, :count).by(1)

        subscription = customer.subscriptions.find_by(external_id: customer.external_id)
        sub_invoice = subscription.invoices.first
        expect(sub_invoice.total_amount_cents).to eq(6000) # Full period is billed

        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(1).to(2)
          .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

        term_invoice = subscription.invoices.order(sequential_id: :desc).first
        expect(term_invoice.total_amount_cents).to eq(0)

        credit_note = sub_invoice.credit_notes.first
        expect(credit_note).to have_attributes(
          sub_total_excluding_taxes_amount_cents: 4821,
          taxes_amount_cents: 964,
          credit_amount_cents: 5785,
          total_amount_cents: 5785
        )
      end
    end

    context "when customer is in UTC+ timezone" do
      let(:customer) { create(:customer, organization:, timezone: "Asia/Tokyo") }

      it "creates expected credit note and invoice" do
        ### 8 Feb: Create and terminate subscription
        feb8 = DateTime.new(2023, 2, 8)

        travel_to(feb8) do
          expect {
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "anniversary"
              }
            )
          }.to change(Invoice, :count).by(1)

          subscription = customer.subscriptions.find_by(external_id: customer.external_id)
          sub_invoice = subscription.invoices.first
          expect(sub_invoice.total_amount_cents).to eq(6000) # Full period is billed

          expect {
            terminate_subscription(subscription)
          }.to change { subscription.reload.status }.from("active").to("terminated")
            .and change { subscription.invoices.count }.from(1).to(2)
            .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

          term_invoice = subscription.invoices.order(sequential_id: :desc).first
          expect(term_invoice.total_amount_cents).to eq(0)

          credit_note = sub_invoice.credit_notes.first
          expect(credit_note).to have_attributes(
            sub_total_excluding_taxes_amount_cents: 4821,
            taxes_amount_cents: 964,
            credit_amount_cents: 5785,
            total_amount_cents: 5785
          )
        end
      end
    end

    context "when customer is in UTC- timezone" do
      let(:customer) { create(:customer, organization:, timezone: "America/Los_Angeles") }

      it "creates expected credit note and invoice" do
        ### 8 Feb: Create and terminate subscription
        feb8 = DateTime.new(2023, 2, 8)

        travel_to(feb8) do
          expect {
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "anniversary"
              }
            )
          }.to change(Invoice, :count).by(1)

          subscription = customer.subscriptions.find_by(external_id: customer.external_id)
          sub_invoice = subscription.invoices.first
          expect(sub_invoice.total_amount_cents).to eq(6000) # Full period is billed

          expect {
            terminate_subscription(subscription)
          }.to change { subscription.reload.status }.from("active").to("terminated")
            .and change { subscription.invoices.count }.from(1).to(2)
            .and change { sub_invoice.reload.credit_notes.count }.from(0).to(1)

          term_invoice = subscription.invoices.order(sequential_id: :desc).first
          expect(term_invoice.total_amount_cents).to eq(0)

          credit_note = sub_invoice.credit_notes.first
          expect(credit_note).to have_attributes(
            sub_total_excluding_taxes_amount_cents: 4821,
            taxes_amount_cents: 964,
            credit_amount_cents: 5785,
            total_amount_cents: 5785
          )
        end
      end
    end
  end
end
