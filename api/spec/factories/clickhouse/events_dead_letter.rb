# frozen_string_literal: true

FactoryBot.define do
  factory :clickhouse_events_dead_letter, class: "Clickhouse::EventsDeadLetter" do
    transient do
      subscription { create(:subscription, customer:) }
      customer { create(:customer) }
      organization { customer.organization }
      billable_metric { create(:billable_metric, organization: organization) }
    end

    organization_id { organization.id }
    external_subscription_id { subscription.external_id }
    code { billable_metric.code }
    timestamp { Time.current }
    failed_at { Time.current }
    ingested_at { Time.current }
    transaction_id { "tr_#{SecureRandom.hex}" }
    error_code { "fetch_billable_metric" }
    error_message { "Error fetching billable metric" }
    initial_error_message { "record not found" }
    event do
      {
        event: {
          organization_id: organization_id,
          external_subscription_id: external_subscription_id,
          transaction_id: transaction_id,
          code: code,
          properties: {
            value: 42
          },
          precise_total_amount_cents: "0.0",
          source: "http_ruby",
          timestamp: timestamp.to_f.to_s,
          source_metadata: {
            api_post_processed: true
          },
          ingested_at: ingested_at.iso8601(3)
        },
        initial_error_message: "record not found",
        error_message: "Error fetching billable metric",
        error_code: "fetch_billable_metric",
        failed_at: failed_at.iso8601(3)
      }
    end
  end
end
