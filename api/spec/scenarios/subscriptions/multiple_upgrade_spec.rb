# frozen_string_literal: true

require "rails_helper"

describe "Multiple Subscription Upgrade Scenario" do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: []) }

  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 25) }

  let(:plan1) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 1_000,
      pay_in_advance: true
    )
  end

  let(:plan2) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 1_500,
      pay_in_advance: true
    )
  end

  let(:plan3) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 1_900,
      pay_in_advance: true
    )
  end

  let(:subscription_at) { Time.zone.parse("2024-03-05T12:12:00") }

  before { tax }

  context "with calendar billing" do
    it "upgrades and bill subscriptions" do
      subscription = nil

      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan1.code,
            billing_time: "calendar"
          }
        )

        expect(customer.invoices.count).to eq(1)

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(1)

        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(871) # 1000 / 31 * (31 - 4)
      end

      travel_to(Time.zone.parse("2024-03-12T12:12:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan2.code,
            billing_time: "calendar"
          }
        )

        expect(customer.invoices.count).to eq(2)
        expect(subscription.reload).to be_terminated

        subscription = customer.subscriptions.order(created_at: :desc).first
        expect(subscription).to be_active

        expect(subscription.invoices.count).to eq(1)
        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(968) # 1500 / 31 * 20

        expect(customer.credit_notes.count).to eq(1)
        credit_note = customer.credit_notes.first
        expect(credit_note.credit_amount_cents).to eq(806) # 1000 / 31 * 20 * 1.25
      end

      travel_to(Time.zone.parse("2024-03-12T13:12:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan3.code,
            billing_time: "calendar"
          }
        )

        perform_all_enqueued_jobs
        expect(customer.invoices.count).to eq(3)
        expect(subscription.reload).to be_terminated

        subscription = customer.subscriptions.order(created_at: :desc).first
        expect(subscription).to be_active

        expect(subscription.invoices.count).to eq(1)
        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(1226) # 1900 / 31 * 20

        expect(customer.credit_notes.count).to eq(2)
        credit_note = customer.credit_notes.order(created_at: :desc).first
        expect(credit_note.credit_amount_cents).to eq(1210) # 1500 / 31 * 20 * 1.25
      end
    end
  end

  context "with anniversary billing" do
    it "upgrades and bill subscriptions" do
      subscription = nil

      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan1.code,
            billing_time: "anniversary"
          }
        )

        expect(customer.invoices.count).to eq(1)

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(1)

        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(1000)
      end

      travel_to(Time.zone.parse("2024-03-12T12:12:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan2.code,
            billing_time: "anniversary"
          }
        )

        expect(customer.invoices.count).to eq(2)
        expect(subscription.reload).to be_terminated

        subscription = customer.subscriptions.order(created_at: :desc).first
        expect(subscription).to be_active

        expect(subscription.invoices.count).to eq(1)
        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(1161) # 1500 / 31 * 24

        expect(customer.credit_notes.count).to eq(1)
        credit_note = customer.credit_notes.first
        expect(credit_note.credit_amount_cents).to eq(968) # 1000 / 31 * 24 * 1.25
      end

      travel_to(Time.zone.parse("2024-03-12T13:12:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan3.code,
            billing_time: "anniversary"
          }
        )

        perform_all_enqueued_jobs
        expect(customer.invoices.count).to eq(3)
        expect(subscription.reload).to be_terminated

        subscription = customer.subscriptions.order(created_at: :desc).first
        expect(subscription).to be_active

        expect(subscription.invoices.count).to eq(1)
        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(1471) # 1900 / 31 * 24

        expect(customer.credit_notes.count).to eq(2)
        credit_note = customer.credit_notes.order(created_at: :desc).first
        expect(credit_note.credit_amount_cents).to eq(1451) # 1500 / 31 * 24 * 1.25
      end
    end
  end
end
