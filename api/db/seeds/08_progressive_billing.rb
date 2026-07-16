# frozen_string_literal: true

subscription = Subscription.find_by!(external_id: "sub_john-doe-main")

UsageThresholds::UpdateService.call!(
  model: subscription.plan,
  usage_thresholds_params: [{
    amount_cents: 120_00,
    threshold_display_name: "Initial Threshold"
  }, {
    amount_cents: 1_000_00,
    threshold_display_name: "Recurring Threshold",
    recurring: true
  }],
  partial: false
)

Subscriptions::UpdateUsageThresholdsService.call!(
  subscription:,
  usage_thresholds_params: [{
    amount_cents: 400_00,
    threshold_display_name: "Initial Threshold"
  }, {
    amount_cents: 800_00
  }, {
    amount_cents: 2000_00,
    recurring: true
  }],
  partial: false
)
