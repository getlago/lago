# frozen_string_literal: true

# NOTE: If hooli is not found, run 01_base.rb first
organization = Organization.find_by!(name: "Hooli")
sum_bm = BillableMetric.find_by!(organization:, code: "sum_bm")
subscription = Subscription.find_by!(external_id: "sub_john-doe-main")

existing_alerts = UsageMonitoring::Alert.where(organization:, subscription_external_id: subscription.external_id)
UsageMonitoring::TriggeredAlert.where(alert: existing_alerts).delete_all
UsageMonitoring::AlertThreshold.where(alert: existing_alerts).delete_all
existing_alerts.delete_all

UsageMonitoring::CreateAlertService.call!(organization:, alertable: subscription, params: {
  alert_type: "current_usage_amount",
  code: "default",
  name: "Default Alert",
  thresholds: [
    {code: "warn", value: 80_00},
    {code: "alert", value: 100_00},
    {code: "panic", value: 33_00, recurring: true}
  ]
})

if License.premium?
  alert = UsageMonitoring::CreateAlertService.call!(organization:, alertable: subscription, params: {
    alert_type: "lifetime_usage_amount",
    code: "total",
    thresholds: [
      {code: "info", value: 1000_00}
    ]
  }).alert

  triggered_alert = UsageMonitoring::TriggeredAlert.create!(alert:, organization:, subscription:,
    current_value: 51,
    previous_value: 8,
    crossed_thresholds: [
      {code: nil, value: 10, recurring: false}, {code: :warn, value: 25, recurring: false}, {code: :alert, value: 50, recurring: false}
    ],
    triggered_at: 2.months.ago)
  SendWebhookJob.perform_later("alert.triggered", triggered_alert)

  triggered_alert = UsageMonitoring::TriggeredAlert.create!(alert:, organization:, subscription:,
    current_value: 88,
    previous_value: 234,
    crossed_thresholds: [
      {code: :alert, value: 100, recurring: false}, {code: :alert, value: 150, recurring: true}, {code: :alert, value: 200, recurring: true}
    ],
    triggered_at: 11.days.ago)
  SendWebhookJob.perform_later("alert.triggered", triggered_alert)
end

bm_alert = UsageMonitoring::CreateAlertService.call(organization:, alertable: subscription, params: {
  alert_type: "billable_metric_current_usage_amount",
  billable_metric: sum_bm,
  code: "ops",
  name: "Operations Alert",
  thresholds: [
    {value: 50_00},
    {value: 10_00, recurring: true}
  ]
}).alert

triggered_alert = UsageMonitoring::TriggeredAlert.create!(alert: bm_alert, organization:, subscription:,
  current_value: 8,
  previous_value: 0,
  crossed_thresholds: [
    {code: nil, value: 5, recurring: false}
  ],
  triggered_at: 4.days.ago)
SendWebhookJob.perform_later("alert.triggered", triggered_alert)
