# frozen_string_literal: true

# Seeds the fixtures for the ingestion->current-usage latency benchmark.
# Idempotent. Run inside the api container:
#   docker exec lago_api_dev bin/rails runner tmp/rw_benchmark/seed.rb
#
# Matrix:
#   rwb_count        count_agg, standard charge, no filters
#   rwb_sum_filtered sum_agg(amount), charge filters tier=gold / tier=silver
#   rwb_sum_grouped  sum_agg(amount), pricing_group_keys ["region"]
# across 3 customers/subscriptions (calendar monthly).

ORG_ID = "791d70ac-ec99-41ca-b3ce-af19ee5171fa"

org = Organization.find(ORG_ID)
billing_entity = org.billing_entities.first!

bm_count = BillableMetric.find_or_create_by!(organization: org, code: "rwb_count") do |bm|
  bm.name = "RWB Count"
  bm.aggregation_type = :count_agg
end

bm_sum_filtered = BillableMetric.find_or_create_by!(organization: org, code: "rwb_sum_filtered") do |bm|
  bm.name = "RWB Sum Filtered"
  bm.aggregation_type = :sum_agg
  bm.field_name = "amount"
end

bm_filter = BillableMetricFilter.find_or_create_by!(
  organization: org, billable_metric: bm_sum_filtered, key: "tier"
) { |f| f.values = %w[gold silver] }

bm_sum_grouped = BillableMetric.find_or_create_by!(organization: org, code: "rwb_sum_grouped") do |bm|
  bm.name = "RWB Sum Grouped"
  bm.aggregation_type = :sum_agg
  bm.field_name = "amount"
end

plan = Plan.find_or_create_by!(organization: org, code: "rwb_plan") do |p|
  p.name = "RW Bench"
  p.interval = :monthly
  p.amount_cents = 0
  p.amount_currency = "EUR"
end

Charge.find_or_create_by!(organization: org, plan:, billable_metric: bm_count) do |c|
  c.code = bm_count.code
  c.charge_model = :standard
  c.properties = {"amount" => "1"}
end

charge_filtered = Charge.find_or_create_by!(organization: org, plan:, billable_metric: bm_sum_filtered) do |c|
  c.code = bm_sum_filtered.code
  c.charge_model = :standard
  c.properties = {"amount" => "1"}
end

if charge_filtered.filters.count < 2
  %w[gold silver].each do |tier|
    filter = ChargeFilter.create!(
      organization: org, charge: charge_filtered, properties: {"amount" => "2"}, invoice_display_name: tier
    )
    ChargeFilterValue.create!(
      organization: org, charge_filter: filter, billable_metric_filter: bm_filter, values: [tier]
    )
  end
end

Charge.find_or_create_by!(organization: org, plan:, billable_metric: bm_sum_grouped) do |c|
  c.code = bm_sum_grouped.code
  c.charge_model = :standard
  c.properties = {"amount" => "1", "pricing_group_keys" => ["region"]}
end

3.times do |i|
  customer = Customer.find_or_create_by!(organization: org, external_id: "rwb_cust_#{i}") do |c|
    c.name = "RW Bench Customer #{i}"
    c.billing_entity = billing_entity
    c.currency = "EUR"
  end

  subscription = Subscription.find_or_create_by!(external_id: "rwb_sub_#{i}") do |s|
    s.organization = org
    s.customer = customer
    s.plan = plan
    s.status = :active
    s.billing_time = :calendar
    s.subscription_at = Time.zone.parse("2026-06-01T00:00:00")
    s.started_at = Time.zone.parse("2026-06-01T00:00:00")
    s.billing_entity_id = customer.billing_entity_id
  end

  Subscriptions::BillingPeriods::UpsertService.call(subscription:)
  puts "subscription rwb_sub_#{i}: #{subscription.id}"
end

puts "seeded."
