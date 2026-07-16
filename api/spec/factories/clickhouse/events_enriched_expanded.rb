# frozen_string_literal: true

FactoryBot.define do
  factory :clickhouse_events_enriched_expanded, class: "Clickhouse::EventsEnrichedExpanded" do
    transient do
      subscription { create(:subscription, customer:) }
      customer { create(:customer) }
      organization { customer.organization }
      billable_metric { create(:billable_metric, organization:) }
      charge { create(:standard_charge, billable_metric:, plan: subscription.plan) }
    end

    organization_id { organization.id }
    subscription_id { subscription.id }
    external_subscription_id { subscription.external_id }
    charge_id { charge.id }
    charge_filter_id { "" }
    code { billable_metric.code }
    timestamp { Time.current }
    transaction_id { "tr_#{SecureRandom.hex}" }
    enriched_at { Time.current }
    value { "21.0" }
    aggregation_type { "sum_agg" }
    grouped_by { {} }
    properties { {} }
  end
end
