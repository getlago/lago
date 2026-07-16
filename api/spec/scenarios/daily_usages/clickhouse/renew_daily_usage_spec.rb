# frozen_string_literal: true

require "rails_helper"

describe "Daily Usage last_received_event_on Scenario (Clickhouse)", :premium, cache: :redis, clickhouse: true, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil, premium_integrations:, clickhouse_events_store: true) }
  let(:premium_integrations) { %w[revenue_analytics lifetime_usage] }
  let(:plan) { create(:plan, organization:, name: "Test Plan", code: "test_plan", amount_cents: 10_00) }
  let(:customer) { create(:customer, external_id: "cust_daily_usage_ch", organization:) }

  let(:billable_metric) { create(:sum_billable_metric, organization:, code: "ops", field_name: "ops_count") }
  let(:charge) { create(:standard_charge, billable_metric:, plan:, amount_currency: "EUR", properties: {amount: "5"}) }

  let(:subscription_external_id) { "sub_daily_usage_ch" }

  def send_event!(params)
    create_event({
      transaction_id: "tr_#{SecureRandom.hex(16)}"
    }.merge(params))

    # In production, the Kafka consumer triggers FlagRefreshedJob.
    # Since there's no Kafka in tests, we call it directly.
    subscription = organization.subscriptions.find_by(external_id: params[:external_subscription_id])
    Subscriptions::FlagRefreshedJob.perform_now(subscription.id)
  end

  before { charge }

  it "tracks last_received_event_on through event lifecycle" do
    travel_to(DateTime.new(2025, 1, 1)) do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })
    end

    subscription = customer.subscriptions.sole
    expect(subscription.last_received_event_on).to be_nil

    travel_to(DateTime.new(2025, 1, 5, 12, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 10}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 5))

    travel_to(DateTime.new(2025, 1, 7, 14, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 5}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 7))
  end

  context "with tricky timezone and event at midnight boundary" do
    let(:customer) { create(:customer, external_id: "cust_daily_usage_ch", organization:, timezone: "Asia/Kolkata") }

    it "sets last_received_event_on in customer timezone" do
      travel_to(DateTime.new(2025, 1, 1)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: subscription_external_id,
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.sole

      # Event at 00:01 IST on Jan 6 (= 2025-01-05 18:31 UTC)
      travel_to(Time.zone.parse("2025-01-05 18:31:00")) do
        send_event!(code: billable_metric.code, properties: {ops_count: 7}, external_subscription_id: subscription_external_id)
      end

      subscription.reload
      # In IST (UTC+5:30), 18:31 UTC is 00:01 Jan 6 → date is Jan 6
      expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 6))
    end
  end
end
