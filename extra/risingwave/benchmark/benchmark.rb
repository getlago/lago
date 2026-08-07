# frozen_string_literal: true

# Ingestion -> current-usage latency benchmark, old path (events store /
# ClickHouse via Go events-processor) vs new path (RisingWave projections).
#
# For each (case, subscription, round, path): produce ONE event to
# events-raw via Karafka (both pipelines consume it), then poll the real
# Rails aggregation layer (AggregationFactory -> aggregate, i.e. exactly what
# Fees::ChargeService executes for current usage) until the value reflects
# the event. The read path is toggled per measurement through
# LAGO_RISINGWAVE_USAGE_ENABLED; measurements are interleaved so neither
# path benefits from warm caches.
#
# Run inside the api container:
#   docker exec lago_api_dev bin/rails runner tmp/rw_benchmark/benchmark.rb
#
# ENV: ROUNDS (default 2), POLL_MS (default 200), TIMEOUT_S (default 90),
#      ONLY (substring filter on case key, e.g. ONLY=group)

require "json"

ORG_ID = "791d70ac-ec99-41ca-b3ce-af19ee5171fa"
ROUNDS = (ENV["ROUNDS"] || 2).to_i
POLL = (ENV["POLL_MS"] || 200).to_i / 1000.0
TIMEOUT = (ENV["TIMEOUT_S"] || 90).to_i
AMOUNT = 3

ActiveRecord::Base.logger = nil
Rails.logger.level = :error

org = Organization.find(ORG_ID)
subscriptions = (0..2).map { |i| Subscription.find_by!(external_id: "rwb_sub_#{i}") }
plan = Plan.find_by!(organization: org, code: "rwb_plan")

charges = plan.charges.includes(:billable_metric, :filters).index_by { |c| c.billable_metric.code }
gold_filter = charges.fetch("rwb_sum_filtered").filters.detect { |f| f.invoice_display_name == "gold" }

CASES = [
  {key: "count / no filters", code: "rwb_count", properties: {}, delta: 1, charge_filter: nil, grouped: false},
  {key: "sum / charge filter (tier=gold)", code: "rwb_sum_filtered", properties: {"tier" => "gold", "amount" => AMOUNT},
   delta: AMOUNT, charge_filter: gold_filter, grouped: false},
  {key: "sum / pricing_group_keys (region)", code: "rwb_sum_grouped", properties: {"region" => "eu", "amount" => AMOUNT},
   delta: AMOUNT, charge_filter: nil, grouped: true}
].freeze

def build_aggregator(subscription, charge, charge_filter, grouped)
  dates = Subscriptions::DatesService.new_instance(subscription, Time.current, current_usage: true)
  filters = {}
  filters[:charge_filter] = charge_filter if charge_filter
  filters[:grouped_by] = charge.pricing_group_keys if grouped

  BillableMetrics::AggregationFactory.new_instance(
    charge:,
    current_usage: true,
    subscription:,
    boundaries: {
      from_datetime: dates.from_datetime,
      to_datetime: dates.to_datetime,
      charges_from_datetime: dates.charges_from_datetime,
      charges_to_datetime: dates.charges_to_datetime,
      charges_duration: dates.charges_duration_in_days
    },
    filters:
  )
end

def read_value(subscription, charge, kase)
  aggregator = build_aggregator(subscription, charge, kase[:charge_filter], kase[:grouped])
  result = aggregator.aggregate
  raise "aggregation failed: #{result.error_message rescue result.inspect}" if result.failure?

  if kase[:grouped]
    group = (result.aggregations || []).detect { |a| a.grouped_by == {"region" => "eu"} }
    group ? BigDecimal(group.aggregation.to_s) : BigDecimal(0)
  else
    BigDecimal(result.aggregation.to_s)
  end
end

def produce_event(org, subscription, kase)
  now = Time.current.utc
  payload = {
    organization_id: org.id,
    external_customer_id: subscription.customer.external_id,
    external_subscription_id: subscription.external_id,
    transaction_id: "rwb-#{SecureRandom.hex(8)}",
    timestamp: now.to_f.to_s,
    code: kase[:code],
    precise_total_amount_cents: "0.0",
    properties: kase[:properties],
    ingested_at: now.strftime("%Y-%m-%dT%H:%M:%S.%L"),
    source: "http_ruby",
    source_metadata: {api_post_processed: true}
  }

  Karafka.producer.produce_sync(
    topic: ENV.fetch("LAGO_KAFKA_RAW_EVENTS_TOPIC"),
    key: "#{org.id}-#{subscription.external_id}",
    payload: payload.to_json
  )
end

def measure(org, subscription, charge, kase)
  baseline = read_value(subscription, charge, kase)
  expected = baseline + kase[:delta]

  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  produce_event(org, subscription, kase)

  loop do
    value = read_value(subscription, charge, kase)
    break if value >= expected

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    return nil if elapsed > TIMEOUT

    sleep POLL
  end

  ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
end

# Warm-up: one unmeasured event per (case, subscription) so projection rows
# exist, Go/CH consumers are warm, and first-poll costs are excluded.
puts "warming up..."
CASES.each do |kase|
  charge = charges.fetch(kase[:code])
  subscriptions.each do |subscription|
    produce_event(org, subscription, kase)
  end
end
sleep 15

results = Hash.new { |h, k| h[k] = [] }
aggregator_classes = {}

active_cases = ENV["ONLY"] ? CASES.select { |c| c[:key].include?(ENV["ONLY"]) } : CASES

ROUNDS.times do |round|
  active_cases.each do |kase|
    charge = charges.fetch(kase[:code])
    subscriptions.each do |subscription|
      [["clickhouse", "false"], ["risingwave", "true"]].each do |path, flag|
        ENV["LAGO_RISINGWAVE_USAGE_ENABLED"] = flag
        aggregator_classes[[kase[:key], path]] ||=
          build_aggregator(subscription, charge, kase[:charge_filter], kase[:grouped]).class.name
        latency = measure(org, subscription, charge, kase)
        results[[kase[:key], path]] << latency
        puts format("round=%d sub=%s case=%-34s path=%-10s -> %s",
          round, subscription.external_id, kase[:key], path, latency ? "#{latency}ms" : "TIMEOUT")
      end
    end
  end
end

puts "\n== RESULTS =="
rows = []
results.each do |(kase, path), latencies|
  ok = latencies.compact
  rows << {
    case: kase,
    path:,
    aggregator: aggregator_classes[[kase, path]],
    n: latencies.size,
    timeouts: latencies.count(&:nil?),
    avg_ms: ok.empty? ? nil : (ok.sum / ok.size),
    min_ms: ok.min,
    max_ms: ok.max
  }
end

rows.each { |r| puts r.to_json }
File.write("tmp/rw_benchmark/results.json", JSON.pretty_generate(rows))
puts "written to tmp/rw_benchmark/results.json"
