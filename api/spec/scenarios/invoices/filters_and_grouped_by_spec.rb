# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoices for charges with filters and grouped by" do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: []) }

  let(:customer) { create(:customer, organization:) }

  let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "value") }
  let(:billable_metric_filter1) do
    create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp azure])
  end
  let(:billable_metric_filter2) do
    create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us europe asia])
  end

  let(:plan) { create(:plan, organization:, amount_cents: 0, interval: "monthly", pay_in_advance: false) }
  let(:charge) do
    create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
  end

  let(:charge_filter) { create(:charge_filter, charge:, properties: {amount: "12", grouped_by: %w[country]}) }
  let(:charge_filter_value1) do
    create(:charge_filter_value, charge_filter:, billable_metric_filter: billable_metric_filter1, values: %w[aws])
  end
  let(:charge_filter_value2) do
    create(
      :charge_filter_value,
      charge_filter:,
      billable_metric_filter: billable_metric_filter2,
      values: [ChargeFilterValue::ALL_FILTER_VALUES]
    )
  end

  before do
    charge_filter_value1
    charge_filter_value2
  end

  it "creates a new invoice for charges with filters and grouped by" do
    # Create a subscription
    travel_to(Time.zone.parse("2024-02-25T10:00:00")) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time: "anniversary"
        }
      )
    end

    subscription = customer.subscriptions.first

    # Send an event matching a filter and a group
    travel_to(Time.zone.parse("2024-02-28T10:00:00")) do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {cloud: "aws", region: "us", country: "us", value: 10}
        }
      )
    end

    travel_to(Time.zone.parse("2024-03-01T10:00:00")) do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {cloud: "aws", region: "europe", country: "france", value: 10}
        }
      )
    end

    travel_to(Time.zone.parse("2024-03-02T10:00:00")) do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {cloud: "aws", region: "asia", value: 10}
        }
      )
    end

    travel_to(Time.zone.parse("2024-03-03T10:00:00")) do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {cloud: "gcp", region: "asia", country: "china", value: 10}
        }
      )
    end

    # Fetch the current usage
    travel_to(Time.zone.parse("2024-03-04T10:00:00")) do
      fetch_current_usage(customer:)

      expect(json[:customer_usage][:total_amount_cents]).to eq(46_000)

      expect(json[:customer_usage][:charges_usage].count).to eq(1)
      charge_usage = json[:customer_usage][:charges_usage].first
      expect(charge_usage[:units]).to eq("40.0")
      expect(charge_usage[:events_count]).to eq(4)
      expect(charge_usage[:amount_cents]).to eq(46_000)

      expect(charge_usage[:grouped_usage].count).to eq(4)
      us_group = charge_usage[:grouped_usage].find { |group| group[:grouped_by][:country] == "us" }
      expect(us_group[:amount_cents]).to eq(12_000)
      expect(us_group[:events_count]).to eq(1)
      expect(us_group[:units]).to eq("10.0")
      expect(us_group[:filters].count).to eq(1)
      expect(us_group[:filters].first[:units]).to eq("10.0")
      expect(us_group[:filters].first[:values]).to eq(cloud: %w[aws], region: [ChargeFilterValue::ALL_FILTER_VALUES])

      france_group = charge_usage[:grouped_usage].find { |group| group[:grouped_by][:country] == "france" }
      expect(france_group[:amount_cents]).to eq(12_000)
      expect(france_group[:events_count]).to eq(1)
      expect(france_group[:units]).to eq("10.0")
      expect(france_group[:filters].count).to eq(1)
      expect(france_group[:filters].first[:units]).to eq("10.0")
      expect(france_group[:filters].first[:values]).to eq(
        cloud: %w[aws],
        region: [ChargeFilterValue::ALL_FILTER_VALUES]
      )

      empty_group = charge_usage[:grouped_usage].find { |group| group[:grouped_by][:country].nil? }
      expect(empty_group[:amount_cents]).to eq(12_000)
      expect(empty_group[:events_count]).to eq(1)
      expect(empty_group[:units]).to eq("10.0")
      expect(empty_group[:filters].count).to eq(1)

      aws_filter = empty_group[:filters].find do |filter|
        filter[:values] == {cloud: ["aws"], region: [ChargeFilterValue::ALL_FILTER_VALUES]}
      end
      expect(aws_filter[:units]).to eq("10.0")
      expect(aws_filter[:values]).to eq(cloud: %w[aws], region: [ChargeFilterValue::ALL_FILTER_VALUES])

      empty_filter = charge_usage[:filters].find { |filter| filter[:values].nil? }
      expect(empty_filter[:amount_cents]).to eq(10_000)
      expect(empty_filter[:events_count]).to eq(1)
      expect(empty_filter[:units]).to eq("10.0")
      expect(empty_filter[:values]).to be_nil
    end

    # Run the billing job
    travel_to(Time.zone.parse("2024-03-25T10:00:00")) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)

      invoice = subscription.invoices.last
      expect(invoice.total_amount_cents).to eq(46_000)

      expect(invoice.fees.charge.count).to eq(4)
      us_fee = invoice.fees.charge.find { |fee| fee.grouped_by["country"] == "us" }
      expect(us_fee.amount_cents).to eq(12_000)
      expect(us_fee.events_count).to eq(1)
      expect(us_fee.units).to eq(10.0)
      expect(us_fee.charge_filter).to eq(charge_filter)

      france_fee = invoice.fees.charge.find { |fee| fee.grouped_by["country"] == "france" }
      expect(france_fee.amount_cents).to eq(12_000)
      expect(france_fee.events_count).to eq(1)
      expect(france_fee.units).to eq(10.0)
      expect(france_fee.charge_filter).to eq(charge_filter)

      ungrouped_fee = invoice.fees.charge.find { |fee| fee.grouped_by["country"].nil? }
      expect(ungrouped_fee.amount_cents).to eq(12_000)
      expect(ungrouped_fee.events_count).to eq(1)
      expect(ungrouped_fee.units).to eq(10.0)
      expect(ungrouped_fee.charge_filter).to eq(charge_filter)

      empty_filter = invoice.fees.charge.find { |fee| fee.charge_filter_id.nil? }
      expect(empty_filter.amount_cents).to eq(10_000)
      expect(empty_filter.events_count).to eq(1)
      expect(empty_filter.units).to eq(10)
      expect(empty_filter.charge_filter).to be_nil
    end
  end
end
