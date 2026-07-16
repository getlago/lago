# frozen_string_literal: true

require "rails_helper"

describe "Subscriptions Alerting Scenario", :premium, cache: :redis do
  let(:organization) { create(:organization, premium_integrations:) }
  let(:premium_integrations) { [] }
  let(:plan) { create(:plan, organization:, name: "Premium Plan", code: "premium_plan", amount_cents: 49_00) }
  let(:customer) { create(:customer, external_id: "cust#{external_id}", organization:) }

  let(:billable_metric) { create(:sum_billable_metric, organization:, code: "ops", field_name: "ops_count") }
  let(:charge) { create(:standard_charge, billable_metric:, plan:, amount_currency: "EUR", properties: {amount: "5"}) }

  let(:bm_2) { create(:sum_billable_metric, organization:, code: "api", field_name: "api_count") }
  let(:charge_2) { create(:standard_charge, billable_metric: bm_2, plan:, amount_currency: "EUR", properties: {amount: "100"}) }

  let(:external_id) { "alerting-v1" }
  let(:subscription_external_id) { "sub_#{external_id}" }

  include_context "with webhook tracking"

  def send_event!(params)
    create_event({
      transaction_id: "tr_#{SecureRandom.hex(16)}"
    }.merge(params))
  end

  before do
    charge
    charge_2
  end

  it "monitors activity and trigger alerts" do
    create_subscription({
      external_customer_id: customer.external_id,
      external_id: subscription_external_id,
      plan_code: plan.code
    })
    subscription = customer.subscriptions.sole

    create_alert(subscription_external_id, {alert_type: :current_usage_amount, code: :simple, thresholds: [
      {value: 15_00, code: :warn},
      {value: 30_00, code: :warn},
      {value: 50_00, code: :alert},
      {value: 1230_00, code: :block}
    ]})
    alert = UsageMonitoring::Alert.find(json[:alert][:lago_id])

    create_alert(subscription_external_id, {alert_type: :billable_metric_current_usage_amount, billable_metric_code: bm_2.code, code: :bm,
      thresholds: [
        {value: 15_00, code: :warn},
        {value: 30_00, code: :warn},
        {value: 50_00, code: :alert},
        {value: 1230_00, code: :block}
      ]})
    alert_on_bm = UsageMonitoring::Alert.find(json[:alert][:lago_id])

    # NOTE: Creating alerts flags the subscription as active
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 1
    perform_usage_update
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 0

    send_event!(code: billable_metric.code, properties: {ops_count: 2}, external_subscription_id: subscription_external_id)
    # SubscriptionActivity is created by PostProcessEvents
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 1

    perform_usage_update

    expect(UsageMonitoring::TriggeredAlert.where(alert:).count).to eq(0)

    send_event!(code: billable_metric.code, properties: {ops_count: 2}, external_subscription_id: subscription_external_id)
    send_event!(code: billable_metric.code, properties: {ops_count: 2}, external_subscription_id: subscription_external_id)

    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 1
    perform_usage_update
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 0

    ta = alert.triggered_alerts.sole
    expect(ta.current_value).to eq(3000)
    expect(ta.previous_value).to eq(1000)
    expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
      {code: "warn", value: "1500.0", recurring: false},
      {code: "warn", value: "3000.0", recurring: false}
    ])

    webhooks_sent.find { |w| w[:webhook_type] == "alert.triggered" }.tap do |webhook|
      expect(webhook[:object_type]).to eq("triggered_alert")
      expect(webhook[:triggered_alert]).to include({
        lago_id: ta.id,
        current_value: "3000.0",
        previous_value: "1000.0",
        triggered_at: String
      })
    end

    # WITH EVENTS ON CHARGE WITH SPECIAL ALERT
    send_event!(code: bm_2.code, properties: {api_count: 4}, external_subscription_id: subscription_external_id)
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 1
    perform_usage_update
    expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 0

    expect(alert.triggered_alerts.count).to eq 2
    expect(alert_on_bm.triggered_alerts.count).to eq 1
    expect(webhooks_sent.count { |w| w.dig(:triggered_alert, :alert_type) == "current_usage_amount" }).to eq 2
    expect(webhooks_sent.count { |w| w.dig(:triggered_alert, :alert_type) == "billable_metric_current_usage_amount" }).to eq 1
  end

  context "with recurring thresholds" do
    it "sends alert forever" do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })
      subscription = customer.subscriptions.sole
      create_alert(subscription_external_id, {alert_type: :current_usage_amount, code: :simple, thresholds: [
        {value: 15_00, code: :warn},
        {value: 30_00, code: :warn},
        {value: 10_00, code: :alert, recurring: true}
      ]})
      alert = UsageMonitoring::Alert.find(json[:alert][:lago_id])

      send_event!(code: billable_metric.code, properties: {ops_count: 7}, external_subscription_id: subscription_external_id)

      perform_usage_update
      expect(UsageMonitoring::TriggeredAlert.where(alert:).count).to eq(1)
      expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 0

      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(3500)
      expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
        {code: "warn", value: "1500.0", recurring: false},
        {code: "warn", value: "3000.0", recurring: false}
      ])

      send_event!(code: billable_metric.code, properties: {ops_count: 4}, external_subscription_id: subscription_external_id)

      perform_usage_update
      expect(UsageMonitoring::TriggeredAlert.where(alert:).count).to eq(2)
      ta = alert.triggered_alerts.order(:created_at).last
      expect(ta.current_value).to eq(5500)
      expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
        {code: "alert", value: "4000.0", recurring: true},
        {code: "alert", value: "5000.0", recurring: true}
      ])
    end
  end

  context "with only a recurring threshold (no one-time thresholds)" do
    it "triggers alerts at each recurring step without raising" do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })
      create_alert(subscription_external_id, {
        alert_type: :current_usage_amount,
        code: :recurring_only,
        thresholds: [
          {value: 10_00, code: :alert, recurring: true}
        ]
      })
      alert = UsageMonitoring::Alert.find(json[:alert][:lago_id])

      send_event!(code: billable_metric.code, properties: {ops_count: 7}, external_subscription_id: subscription_external_id)
      perform_usage_update

      expect(alert.triggered_alerts.count).to eq(1)
      ta = alert.triggered_alerts.sole
      expect(ta.current_value).to eq(3_500)
      expect(ta.previous_value).to eq(0)
      expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
        {code: "alert", value: "1000.0", recurring: true},
        {code: "alert", value: "2000.0", recurring: true},
        {code: "alert", value: "3000.0", recurring: true}
      ])

      webhooks_sent.find { |w| w[:webhook_type] == "alert.triggered" }.tap do |webhook|
        expect(webhook[:object_type]).to eq("triggered_alert")
        expect(webhook[:triggered_alert]).to include({
          lago_id: ta.id,
          current_value: "3500.0",
          previous_value: "0.0",
          triggered_at: String
        })
      end

      send_event!(code: billable_metric.code, properties: {ops_count: 4}, external_subscription_id: subscription_external_id)
      perform_usage_update

      expect(alert.triggered_alerts.count).to eq(2)
      ta = alert.triggered_alerts.order(:created_at).last
      expect(ta.current_value).to eq(5500)
      expect(ta.previous_value).to eq(3500)
      expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
        {code: "alert", value: "4000.0", recurring: true},
        {code: "alert", value: "5000.0", recurring: true}
      ])
    end
  end

  context "with billable_metric_current_usage_units alert" do
    it do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })

      create_alert(subscription_external_id, {
        alert_type: :billable_metric_current_usage_units,
        code: :bm_units,
        billable_metric_code: billable_metric.code,
        thresholds: [
          {value: 90, code: :warn}
        ]
      })
      alert_on_bm_units = UsageMonitoring::Alert.find(json[:alert][:lago_id])

      send_event!(code: billable_metric.code, properties: {ops_count: 89}, external_subscription_id: subscription_external_id)
      perform_usage_update
      expect(alert_on_bm_units.triggered_alerts.count).to eq 0

      send_event!(code: billable_metric.code, properties: {ops_count: 5}, external_subscription_id: subscription_external_id)
      perform_usage_update
      expect(alert_on_bm_units.triggered_alerts.count).to eq 1

      ta = alert_on_bm_units.triggered_alerts.sole

      expect(ta.current_value).to eq(94)
      expect(ta.previous_value).to eq(89)
      expect(ta.crossed_thresholds.map(&:symbolize_keys)).to eq([
        {code: "warn", value: "90.0", recurring: false}
      ])

      webhooks_sent.find { |w| w[:webhook_type] == "alert.triggered" }.tap do |webhook|
        expect(webhook[:object_type]).to eq("triggered_alert")
        expect(webhook[:triggered_alert]).to include({
          lago_id: ta.id,
          current_value: "94.0",
          previous_value: "89.0",
          triggered_at: String
        })
      end
    end
  end

  context "with lifetime_usage alerts" do
    let(:premium_integrations) { %i[lifetime_usage progressive_billing] }

    it do
      travel_to(DateTime.new(2025, 1, 1)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: subscription_external_id,
          plan_code: plan.code
        })
      end

      create_alert(subscription_external_id, {
        alert_type: :lifetime_usage_amount,
        code: :lifetime,
        thresholds: [{value: 150_00, code: :warn}]
      })
      lifetime_alert = UsageMonitoring::Alert.find(json[:alert][:lago_id])

      [DateTime.new(2025, 1, 1), DateTime.new(2025, 2, 1)].each do |month|
        travel_to month + 5.days do
          send_event!(code: billable_metric.code, properties: {ops_count: 10}, external_subscription_id: subscription_external_id)
          perform_usage_update
        end
        travel_to((month + 1.month).beginning_of_month) do
          perform_billing
          expect(organization.triggered_alerts.count).to eq 0
        end
      end

      travel_to DateTime.new(2025, 3, 15) do
        send_event!(code: billable_metric.code, properties: {ops_count: 11}, external_subscription_id: subscription_external_id)
        perform_usage_update
      end

      expect(organization.triggered_alerts.count).to eq 1
      ta = organization.triggered_alerts.sole
      expect(ta.usage_monitoring_alert_id).to eq lifetime_alert.id
      expect(ta.current_value).to eq 155_00
      expect(ta.crossed_thresholds).to eq [{"code" => "warn", "value" => "15000.0", "recurring" => false}]
    end
  end

  context "when there is no alert" do
    it "does not track activity" do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: subscription_external_id,
        plan_code: plan.code
      })
      webhooks_sent = []
      subscription = customer.subscriptions.sole

      send_event!(code: billable_metric.code, properties: {ops_count: 20}, external_subscription_id: subscription_external_id)
      expect(UsageMonitoring::SubscriptionActivity.where(subscription:).count).to eq 0

      perform_usage_update

      expect(webhooks_sent).to be_empty
    end
  end
end
