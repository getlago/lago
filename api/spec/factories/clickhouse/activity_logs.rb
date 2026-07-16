# frozen_string_literal: true

FactoryBot.define do
  factory :clickhouse_activity_log, class: "Clickhouse::ActivityLog" do
    transient do
      membership { create(:membership) }
      customer { create(:customer, organization: membership.organization) }
      subscription { create(:subscription, customer:) }
      metric { create(:billable_metric, organization: membership.organization) }
    end

    organization { membership.organization }
    resource { metric }
    user_id { membership.user_id }
    api_key_id { create(:api_key, organization: membership.organization).id }
    external_customer_id { customer.external_id }
    external_subscription_id { subscription.external_id }
    activity_type { "billable_metric.created" }
    activity_source { "api" }
    logged_at { Time.current }
    activity_object { {"foo" => "bar", "baz" => "qux"} }
    activity_object_changes { {"foo" => '{"old": "bar", "new": "baz"}'} }
  end
end
