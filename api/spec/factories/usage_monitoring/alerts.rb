# frozen_string_literal: true

FactoryBot.define do
  factory :alert, class: "UsageMonitoring::Alert" do
    association :organization
    subscription_external_id { create(:subscription, organization: organization).external_id }
    name { "General Alert" }
    sequence(:code) { |n| "default#{n}" }
    alert_type { "current_usage_amount" }
    direction { "increasing" }

    transient do
      thresholds { [15_00] }
      recurring_threshold { nil }
    end

    after(:create) do |alert, evaluator|
      if evaluator.thresholds
        thresholds_attributes = evaluator.thresholds.map do |v|
          {value: v, code: "warn#{v}", organization_id: alert.organization_id}
        end
        alert.thresholds.create! thresholds_attributes
      end

      if evaluator.recurring_threshold
        alert.thresholds.create!({
          value: evaluator.recurring_threshold, code: "rec", recurring: true, organization_id: alert.organization_id
        })
      end
    end
  end

  trait :processed do
    previous_value { 8_00 }
    last_processed_at { DateTime.new(2000, 1, 1, 12, 0, 0) }
  end

  factory :usage_current_amount_alert,
    class: "UsageMonitoring::CurrentUsageAmountAlert",
    parent: :alert do
    alert_type { "current_usage_amount" }
  end

  factory :lifetime_usage_amount_alert,
    class: "UsageMonitoring::LifetimeUsageAmountAlert",
    parent: :alert do
    alert_type { "lifetime_usage_amount" }
  end

  factory :billable_metric_current_usage_amount_alert,
    class: "UsageMonitoring::BillableMetricCurrentUsageAmountAlert",
    parent: :alert do
    alert_type { "billable_metric_current_usage_amount" }
    billable_metric { association(:billable_metric, organization:) }
  end

  factory :billable_metric_current_usage_units_alert,
    class: "UsageMonitoring::BillableMetricCurrentUsageUnitsAlert",
    parent: :alert do
    alert_type { "billable_metric_current_usage_units" }
    billable_metric { association(:billable_metric, organization:) }
  end

  factory :billable_metric_lifetime_usage_units_alert,
    class: "UsageMonitoring::BillableMetricLifetimeUsageUnitsAlert",
    parent: :alert do
    alert_type { "billable_metric_lifetime_usage_units" }
    billable_metric { association(:billable_metric, organization:) }
  end

  factory :wallet_balance_amount_alert,
    class: "UsageMonitoring::WalletBalanceAmountAlert",
    parent: :alert do
    alert_type { "wallet_balance_amount" }
    direction { "decreasing" }
    subscription_external_id { nil }
    wallet { association(:wallet, organization:) }
  end

  factory :wallet_credits_balance_alert,
    class: "UsageMonitoring::WalletCreditsBalanceAlert",
    parent: :alert do
    alert_type { "wallet_credits_balance" }
    direction { "decreasing" }
    subscription_external_id { nil }
    wallet { association(:wallet, organization:) }
  end

  factory :wallet_ongoing_balance_amount_alert,
    class: "UsageMonitoring::WalletOngoingBalanceAmountAlert",
    parent: :alert do
    alert_type { "wallet_ongoing_balance_amount" }
    direction { "decreasing" }
    subscription_external_id { nil }
    wallet { association(:wallet, organization:) }
  end

  factory :wallet_credits_ongoing_balance_alert,
    class: "UsageMonitoring::WalletCreditsOngoingBalanceAlert",
    parent: :alert do
    alert_type { "wallet_credits_ongoing_balance" }
    direction { "decreasing" }
    subscription_external_id { nil }
    wallet { association(:wallet, organization:) }
  end
end
