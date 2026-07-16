# frozen_string_literal: true

require "rails_helper"

describe "Billing Minimum Commitments In Advance Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:) }

  let(:plan) do
    create(
      :plan,
      name: "In Advance",
      code: "in_advance",
      organization:,
      amount_cents: 10_000,
      interval: plan_interval,
      pay_in_advance: true,
      bill_charges_monthly:
    )
  end

  let(:invoice) { subscription.reload.invoices.order(sequential_id: :desc).first }
  let(:subscription) { customer.subscriptions.first.reload }

  let(:billable_metric_advance_metered) do
    create(
      :billable_metric,
      organization:,
      name: "Metered in advance",
      code: "advance_metered",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: false
    )
  end

  let(:billable_metric_metered) do
    create(
      :billable_metric,
      organization:,
      name: "Metered in arrears",
      code: "metered",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: false
    )
  end

  let(:billable_metric_recurring_advance) do
    create(
      :billable_metric,
      organization:,
      name: "In advance recurring",
      code: "recurring_advance",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: true
    )
  end

  let(:billing_time) { "calendar" }
  let(:plan_interval) { "yearly" }
  let(:subscription_time) { DateTime.new(2024, 3, 5, 10) }
  let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

  before do
    minimum_commitment

    create(
      :standard_charge,
      :pay_in_advance,
      billable_metric: billable_metric_advance_metered,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    create(
      :standard_charge,
      billable_metric: billable_metric_metered,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    create(
      :standard_charge,
      :pay_in_advance,
      billable_metric: billable_metric_recurring_advance,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    # Create the subscription
    travel_to(subscription_time) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time:
        }
      )
    end

    travel_to(subscription_time + 1.hour) do
      create_event(
        {
          code: billable_metric_advance_metered.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "2"}
        }
      )

      create_event(
        {
          code: billable_metric_metered.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "1"}
        }
      )

      create_event(
        {
          code: billable_metric_advance_metered.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "30"}
        }
      )

      perform_billing
    end
  end

  context "when billed monthly" do
    let(:bill_charges_monthly) { true }

    context "when subscription is billed for the first period" do
      it "creates an invoice with no minimum commitment fee" do
        travel_to(subscription_time + 1.minute) do
          expect(invoice.fees.commitment.count).to eq(0)
        end
      end
    end

    context "when subscription is billed for the last period" do
      before do
        travel_to(subscription_time + 5.months) do
          create_event(
            {
              code: billable_metric_advance_metered.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {total: "55"}
            }
          )
        end

        travel_to(subscription_time + 11.months) do
          create_event(
            {
              code: billable_metric_metered.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {total: "1"}
            }
          )
        end

        # { DateTime.new(2025, 3, 01) }
        travel_to((subscription_time + 12.months).beginning_of_month) do
          perform_billing
        end

        # { DateTime.new(2025, 01, 01) }
        travel_to((subscription_time + 1.year).beginning_of_year) do
          perform_billing
        end
      end

      it "creates an invoice with minimum commitment fee" do
        # { DateTime.new(2025, 01, 01) }
        travel_to((subscription_time + 1.year).beginning_of_year) do
          expect(invoice.fees.commitment.count).to eq(1)
          expect(invoice.fees.commitment.sum(:amount_cents)).to eq(808_186)
        end
      end
    end
  end
end
