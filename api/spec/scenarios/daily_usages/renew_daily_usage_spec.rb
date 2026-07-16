# frozen_string_literal: true

require "rails_helper"

describe "Daily Usage last_received_event_on Scenario", :premium, cache: :redis do
  let(:organization) { create(:organization, webhook_url: nil, premium_integrations:) }
  let(:premium_integrations) { %w[revenue_analytics lifetime_usage] }
  let(:plan) { create(:plan, organization:, name: "Test Plan", code: "test_plan", amount_cents: 10_00) }
  let(:customer) { create(:customer, external_id: "cust_daily_usage", organization:) }

  let(:billable_metric) { create(:sum_billable_metric, organization:, code: "ops", field_name: "ops_count") }
  let(:charge) { create(:standard_charge, billable_metric:, plan:, amount_currency: "EUR", properties: {amount: "5"}) }

  let(:subscription_external_id) { "sub_daily_usage" }

  def send_event!(params)
    create_event({
      transaction_id: "tr_#{SecureRandom.hex(16)}"
    }.merge(params))
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

    # Sending an event sets last_received_event_on to today in customer's timezone
    travel_to(DateTime.new(2025, 1, 5, 12, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 10}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 5))

    # Running job at midnight same day (Jan 6 00:05 UTC) — queries for last_received_event_on = yesterday (Jan 5)
    # This matches! So daily usage for Jan 5 is computed.
    travel_to(DateTime.new(2025, 1, 6, 0, 5, 0)) do
      perform_usage_update
    end

    expect(DailyUsage.where(subscription:).count).to eq(1)

    # Sending another event updates the date
    travel_to(DateTime.new(2025, 1, 7, 14, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 5}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 7))
  end

  # Scenario: Multi-day lifecycle with late-arriving events and idle days.
  #
  # Day 1 (Jan 5):  12:00 - event_0 received
  # Day 2 (Jan 6):  00:15 - recalculate → includes event_0
  # Day 3 (Jan 7):  00:15 - no recalculation (last_received_event_on = Jan 5 < yesterday Jan 6)
  # Day 4 (Jan 8):  12:00 - event_1 received
  # Day 5 (Jan 9):  00:01 - event_2 received (backdated to Jan 7)
  #                  00:10 - event_3 received
  #                  00:15 - recalculate → includes event_0, event_1, event_2 but not event_3
  # Day 6 (Jan 10): 00:15 - recalculate → includes event_3
  #
  # Key behavior tested: the >= condition on last_received_event_on allows the subscription
  # to be selected on day 5 even though last_received_event_on is today (Jan 9), not yesterday (Jan 8).
  it "handles multi-day lifecycle with late-arriving events and idle days" do
    travel_to(DateTime.new(2025, 1, 1)) do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })
    end

    subscription = customer.subscriptions.sole

    ## Day 1 (Jan 5): event_0 received at 12:00
    travel_to(DateTime.new(2025, 1, 5, 12, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 10}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 5))

    ## Day 2 (Jan 6): 00:15 - recalculate usage, includes event_0
    # last_received_event_on = Jan 5 >= yesterday (Jan 5) → match
    travel_to(DateTime.new(2025, 1, 6, 0, 15, 0)) do
      perform_usage_update
    end

    expect(DailyUsage.where(subscription:).count).to eq(1)
    day1_usage = DailyUsage.where(subscription:, usage_date: Date.new(2025, 1, 5)).sole
    # event_0: 10 ops * 5 EUR = 5000 cents
    expect(day1_usage.usage["amount_cents"]).to eq(5000)

    ## Day 3 (Jan 7): 00:15 - no recalculation
    # last_received_event_on = Jan 5 >= yesterday (Jan 6) → false → subscription NOT selected
    travel_to(DateTime.new(2025, 1, 7, 0, 15, 0)) do
      perform_usage_update
    end

    expect(DailyUsage.where(subscription:).count).to eq(1) # still only 1 record

    ## Day 4 (Jan 8): event_1 received at 12:00
    travel_to(DateTime.new(2025, 1, 8, 12, 0, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 5}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 8))

    ## Day 5 (Jan 9): event_2 at 00:01 (backdated to Jan 7)
    # event_2 is received today but its timestamp is 2 days ago
    travel_to(DateTime.new(2025, 1, 9, 0, 1, 0)) do
      send_event!(
        code: billable_metric.code,
        properties: {ops_count: 3},
        external_subscription_id: subscription_external_id,
        timestamp: DateTime.new(2025, 1, 7, 12, 0, 0).to_i
      )
    end

    subscription.reload
    # last_received_event_on is set to current date (Jan 9), not the event's backdated timestamp
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 9))

    ## Day 5 (Jan 9): 00:15 - recalculate usage
    # last_received_event_on = Jan 9 >= yesterday (Jan 8) → match (this is why >= matters!)
    # Includes event_0 (10) + event_1 (5) + event_2 (3) = 18 ops * 5 EUR = 9000 cents
    # event_3 is NOT yet received
    travel_to(DateTime.new(2025, 1, 9, 0, 15, 0)) do
      perform_usage_update
    end

    expect(DailyUsage.where(subscription:).count).to eq(2)
    day4_usage = DailyUsage.where(subscription:, usage_date: Date.new(2025, 1, 8)).sole
    expect(day4_usage.usage["amount_cents"]).to eq(9000)

    ## Day 5 (Jan 9): event_3 received (after the job ran)
    travel_to(DateTime.new(2025, 1, 9, 0, 20, 0)) do
      send_event!(code: billable_metric.code, properties: {ops_count: 7}, external_subscription_id: subscription_external_id)
    end

    subscription.reload
    expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 9))

    ## Day 6 (Jan 10): 00:15 - recalculate usage, includes event_3
    # last_received_event_on = Jan 9 >= yesterday (Jan 9) → match
    # Includes all events: event_0 (10) + event_1 (5) + event_2 (3) + event_3 (7) = 25 ops * 5 EUR = 12500 cents
    travel_to(DateTime.new(2025, 1, 10, 0, 15, 0)) do
      perform_usage_update
    end

    expect(DailyUsage.where(subscription:).count).to eq(3)
    day5_usage = DailyUsage.where(subscription:, usage_date: Date.new(2025, 1, 9)).sole
    expect(day5_usage.usage["amount_cents"]).to eq(12_500)
  end

  # Scenario: event arrives at 00:01 local time (just after midnight), job runs at 00:02.
  # The event belongs to the NEW day so the job looking for "yesterday" won't pick it up.
  # The next day's job run WILL process it.
  #
  # Using Asia/Kolkata (UTC+5:30) — a non-standard half-hour offset timezone.
  # 2025-01-05 18:31 UTC = 2025-01-06 00:01 IST → event date is Jan 6 in customer TZ
  # 2025-01-05 18:32 UTC = 2025-01-06 00:02 IST → job queries last_received_event_on = Jan 5 → no match (it's Jan 6)
  # 2025-01-06 18:32 UTC = 2025-01-07 00:02 IST → job queries last_received_event_on = Jan 6 → match!
  context "with tricky timezone and event at midnight boundary" do
    let(:customer) { create(:customer, external_id: "cust_daily_usage", organization:, timezone: "Asia/Kolkata") }

    it "defers midnight event to next day's daily usage computation" do
      travel_to(DateTime.new(2025, 1, 1)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: subscription_external_id,
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.sole

      # Send an earlier event on Jan 4 (IST) so there's something to compute
      # 2025-01-04 12:00 UTC = 2025-01-04 17:30 IST
      travel_to(Time.zone.parse("2025-01-04 12:00:00")) do
        send_event!(code: billable_metric.code, properties: {ops_count: 3}, external_subscription_id: subscription_external_id)
      end

      subscription.reload
      expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 4))

      # Job runs at 00:05 IST on Jan 5 (= 2025-01-04 18:35 UTC)
      # Queries last_received_event_on = Jan 4 (yesterday in IST) → match
      travel_to(Time.zone.parse("2025-01-04 18:35:00")) do
        perform_usage_update
      end

      expect(DailyUsage.where(subscription:).count).to eq(1)
      jan4_usage = DailyUsage.where(subscription:).last
      expect(jan4_usage.usage_date).to eq(Date.new(2025, 1, 4))

      # Event_a arrives at 00:01 IST on Jan 6 (= 2025-01-05 18:31 UTC)
      travel_to(Time.zone.parse("2025-01-05 18:31:00")) do
        send_event!(code: billable_metric.code, properties: {ops_count: 7}, external_subscription_id: subscription_external_id)
      end

      subscription.reload
      # last_received_event_on = Jan 6 (customer's local date)
      expect(subscription.last_received_event_on).to eq(Date.new(2025, 1, 6))

      # Job runs at 00:02 IST on Jan 6 (= 2025-01-05 18:32 UTC)
      # Queries last_received_event_on = Jan 5 (yesterday in IST)
      # But last_received_event_on is Jan 6 → NO match → subscription NOT selected
      travel_to(Time.zone.parse("2025-01-05 18:32:00")) do
        perform_usage_update
      end

      # No new daily usage was created for Jan 5
      expect(DailyUsage.where(subscription:, usage_date: Date.new(2025, 1, 5)).count).to eq(0)

      # Next day: job runs at 00:02 IST on Jan 7 (= 2025-01-06 18:32 UTC)
      # Queries last_received_event_on = Jan 6 → MATCH → subscription selected
      # Computes daily usage for Jan 6 which now includes event_a
      travel_to(Time.zone.parse("2025-01-06 18:32:00")) do
        perform_usage_update
      end

      jan6_usage = DailyUsage.where(subscription:, usage_date: Date.new(2025, 1, 6)).first
      expect(jan6_usage).to be_present
      # Jan 6 usage should include both events (3 + 7 = 10 ops_count → 50 amount_cents at rate "5")
      expect(jan6_usage.usage["amount_cents"]).to eq(5000)
    end
  end
end
