# frozen_string_literal: true

require "rails_helper"

describe "Progressive Billing enablement", :premium, transaction: false do
  let(:timezone) { "UTC" }
  let(:organization) { create(:organization, webhook_url: nil, premium_integrations: ["progressive_billing"]) }
  let(:billable_metric) { create(:sum_billable_metric, organization:) }

  let(:customer) { create(:customer, organization:, timezone:) }
  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 5_000_000
    )
  end

  let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"}) }
  let(:usage_threshold) { create(:usage_threshold, plan: plan, amount_cents: 20000) }

  before do
    charge
  end

  context "when enabled when usage has already been accumulating" do
    it "correctly calculates thresholds and generates correct progressive billing invoices" do
      time_0 = DateTime.new(2022, 12, 1)
      travel_to time_0

      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        }
      )

      subscription = customer.subscriptions.first

      # no invoice expected to be generated
      travel_to time_0 + 5.days

      ingest_event(subscription, billable_metric, 1000000)
      expect(Invoice.count).to eq(0)

      # update plan and add a threshold
      travel_to time_0 + 6.days

      update_plan(plan, {usage_thresholds: [
        {
          amount_cents: usage_threshold.amount_cents
        }
      ]})

      perform_all_enqueued_jobs
      perform_usage_update

      expect(Invoice.count).to eq(1)
      invoice = Invoice.last

      expect(invoice.invoice_type).to eq("progressive_billing")
      expect(invoice.total_amount_cents).to eq(1000000 * 10 * 100)

      travel_to time_0 + 1.month

      perform_billing
      expect(Invoice.count).to eq(2)

      recurring_invoice = subscription.invoices.order(:created_at).last
      expect(recurring_invoice.total_amount_cents).to eq(5_000_000)
      expect(recurring_invoice.fees_amount_cents).to eq(5_000_000 + 1000000 * 10 * 100)
      expect(recurring_invoice.progressive_billing_credit_amount_cents).to eq(1000000 * 10 * 100)
    end
  end

  context "when enabled when usage has already been invoiced" do
    it "correctly calculates thresholds and generates correct progressive billing invoices" do
      time_0 = DateTime.new(2022, 12, 1)
      travel_to time_0

      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        }
      )

      subscription = customer.subscriptions.first

      # no invoice expected to be generated
      travel_to time_0 + 5.days

      ingest_event(subscription, billable_metric, 1000000)
      expect(Invoice.count).to eq(0)

      travel_to time_0 + 31.days
      perform_billing
      expect(Invoice.count).to eq(1)

      invoice = Invoice.last
      expect(invoice.invoice_type).to eq("subscription")
      expect(invoice.total_amount_cents).to eq(5_000_000 + 1000000 * 10 * 100)

      # update plan and add a threshold
      travel_to time_0 + 36.days

      update_plan(plan, {usage_thresholds: [
        {
          amount_cents: usage_threshold.amount_cents
        }
      ]})

      perform_all_enqueued_jobs
      perform_usage_update

      expect(Invoice.count).to eq(1)
    end
  end
end
