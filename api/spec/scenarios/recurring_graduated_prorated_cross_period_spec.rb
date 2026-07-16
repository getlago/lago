# frozen_string_literal: true

require "rails_helper"

describe "Recurring graduated prorated usage across billing periods", transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) do
    create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly")
  end
  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "sum_agg",
      field_name: "amount",
      recurring: true
    )
  end
  let(:subscription) { customer.subscriptions.first }

  let(:period_one_start) { DateTime.new(2026, 4, 8, 12, 0, 0) }
  let(:period_two_start) { DateTime.new(2026, 5, 8, 0, 1, 0) }
  let(:in_period_two) { DateTime.new(2026, 5, 9, 12, 0, 0) }

  before do
    create(
      :graduated_charge,
      plan:,
      billable_metric:,
      prorated: true,
      pay_in_advance: false,
      properties: {
        graduated_ranges: [
          {from_value: 0, to_value: 2, per_unit_amount: "0", flat_amount: "0"},
          {from_value: 3, to_value: nil, per_unit_amount: "150", flat_amount: "0"}
        ]
      }
    )

    travel_to(period_one_start) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          subscription_at: period_one_start.iso8601,
          billing_time: "anniversary"
        }
      )
    end
  end

  it "prices the net 1 unit at 0 cents (free tier) after periods cross" do
    travel_to(period_two_start - 1.hour) do
      3.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: -1}
          }
        )
      end
    end

    travel_to(period_two_start) do
      BillSubscriptionJob.perform_now([subscription], Time.current, invoicing_reason: :subscription_periodic)
    end

    period_one_invoice = subscription.invoices.order(:created_at).last
    expect(period_one_invoice.total_amount_cents).to eq(0)

    travel_to(in_period_two) do
      4.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: 1}
          }
        )
      end

      fetch_current_usage(customer:)
    end

    charge_usage = json[:customer_usage][:charges_usage].first

    expect(charge_usage[:units]).to eq("1.0")
    expect(charge_usage[:amount_cents]).to eq(0)
  end

  it "reflects backdated events from period 1 in the period 2 running sum" do
    travel_to(period_one_start + 1.day) do
      3.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: -1}
          }
        )
      end
    end

    travel_to(period_two_start) do
      BillSubscriptionJob.perform_now([subscription], Time.current, invoicing_reason: :subscription_periodic)
    end

    travel_to(in_period_two) do
      4.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: 1}
          }
        )
      end

      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {amount: 1},
          timestamp: (period_one_start + 5.days).to_i
        }
      )

      fetch_current_usage(customer:)
    end

    charge_usage = json[:customer_usage][:charges_usage].first
    expect(charge_usage[:units]).to eq("2.0")
  end
end
