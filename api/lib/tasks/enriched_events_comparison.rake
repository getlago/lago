# frozen_string_literal: true

require "json"

namespace :enriched_events do
  desc "Compare ClickhouseStore vs ClickhouseEnrichedStore usage for given subscription IDs"
  task :compare, [:subscription_id] => :environment do |_task, args|
    Rails.logger.level = Logger::Severity::ERROR

    abort "Usage: [QUIET=true] [DEDUPLICATE=true] [FORMAT=json] rake enriched_events:compare[sub_id_1,sub_id_2,...]\n\n" unless args[:subscription_id]
    abort "[SKIP] Clickhouse is not enabled on this system" if ENV["LAGO_CLICKHOUSE_ENABLED"].blank?

    quiet = ENV.fetch("QUIET", "false") == "true"
    deduplicate = ENV.fetch("DEDUPLICATE", "false") == "true"
    format_json = ENV.fetch("FORMAT", "").downcase == "json"

    log = format_json ? ->(_msg) {} : ->(msg) { puts msg }
    json_results = [] if format_json

    subscription_ids = [args[:subscription_id]] + args.extras
    total_diffs = 0
    total_legacy_elapsed = 0.0
    total_enriched_elapsed = 0.0

    subscription_ids.each do |sub_id|
      log.call("\n#{"=" * 80}")
      log.call("Subscription: #{sub_id}")
      log.call("=" * 80)

      subscription = Subscription.includes(:customer, plan: :organization).find_by(id: sub_id)

      if subscription.nil?
        log.call("[SKIP] Subscription not found")
        json_results&.push({subscription_id: sub_id, status: "skipped", reason: "Subscription not found"})
        next
      end

      organization = subscription.plan.organization

      unless organization.clickhouse_events_store?
        log.call("[SKIP] Organization #{organization.id} does not use ClickHouse")
        json_results&.push({subscription_id: sub_id, status: "skipped", reason: "Organization does not use ClickHouse"})
        next
      end

      comparison_result = Events::Stores::Clickhouse::EnrichedStoreMigration::ComparisonService.call(
        subscription:,
        deduplicate:
      )

      unless comparison_result.success?
        log.call("[ERROR] Comparison failed: #{comparison_result.error&.message}")
        json_results&.push({subscription_id: sub_id, status: "error", reason: comparison_result.error&.message})
        next
      end

      legacy_elapsed = comparison_result.legacy_elapsed
      enriched_elapsed = comparison_result.enriched_elapsed
      total_legacy_elapsed += legacy_elapsed
      total_enriched_elapsed += enriched_elapsed

      sub_diffs = comparison_result.diff_count
      total_diffs += sub_diffs
      fee_details = [] if format_json

      comparison_result.fee_details.each do |detail|
        parts = ["charge=#{detail.charge_id}"]
        parts << "filter=#{detail.charge_filter_id}" if detail.charge_filter_id
        parts << "metric=#{detail.billable_metric_code}" if detail.billable_metric_code
        parts << "grouped_by=#{detail.grouped_by}" if detail.grouped_by.present?
        parts << "agg=#{detail.aggregation_type}" if detail.aggregation_type
        parts << "model=#{detail.charge_model}" if detail.charge_model
        parts << "from=#{detail.from}" if detail.from
        parts << "to=#{detail.to}" if detail.to
        label = parts.join(" ")

        case detail.status
        when "only_in_legacy"
          log.call("  [ONLY IN LEGACY]  #{label}")
        when "only_in_enriched"
          log.call("  [ONLY IN ENRICHED] #{label}")
        when "diff"
          log.call("  [DIFF]  #{label}")
          unless format_json
            detail.diffs.each do |field, values|
              log.call("          #{field}: legacy=#{values.legacy} enriched=#{values.enriched}")
            end
          end
        when "match"
          log.call("  [MATCH] #{label}") unless quiet
        end

        if format_json && (detail.status != "match" || !quiet)
          fee_details << detail.to_h
        end
      end

      timing_info = build_timing(legacy_elapsed, enriched_elapsed)
      log.call("\n  Summary: #{comparison_result.fee_details.size} fee(s), #{sub_diffs} difference(s)")
      log.call("  Timing: legacy=#{legacy_elapsed.round(3)}s enriched=#{enriched_elapsed.round(3)}s #{timing_info[:comparison]}")

      if format_json
        json_results << {
          subscription_id: sub_id,
          status: "compared",
          timing: {legacy_seconds: legacy_elapsed.round(3), enriched_seconds: enriched_elapsed.round(3), speedup: timing_info[:speedup]},
          fee_count: comparison_result.fee_details.size,
          diff_count: sub_diffs,
          fees: fee_details
        }
      end
    end

    total_timing = build_timing(total_legacy_elapsed, total_enriched_elapsed)
    log.call("\n#{"=" * 80}")
    log.call("Total differences across all subscriptions: #{total_diffs}")
    log.call("Total timing: legacy=#{total_legacy_elapsed.round(3)}s enriched=#{total_enriched_elapsed.round(3)}s #{total_timing[:comparison]}")
    log.call("=" * 80)

    if format_json
      output = {
        generated_at: Time.current.iso8601,
        options: {quiet: quiet, deduplicate: deduplicate},
        total_diffs: total_diffs,
        total_subscriptions: subscription_ids.size,
        total_timing: {legacy_seconds: total_legacy_elapsed.round(3), enriched_seconds: total_enriched_elapsed.round(3), speedup: total_timing[:speedup]},
        subscriptions: json_results
      }
      puts JSON.pretty_generate(output)
    end
  end

  private

  def build_timing(legacy_elapsed, enriched_elapsed)
    if enriched_elapsed.zero?
      {speedup: nil, comparison: "enriched=0s"}
    elsif legacy_elapsed.zero?
      {speedup: nil, comparison: "legacy=0s"}
    else
      speedup = (legacy_elapsed / enriched_elapsed).round(2)
      comparison = if speedup >= 1.0
        "speedup=#{speedup}x (enriched is faster)"
      else
        "slowdown=#{(1.0 / speedup).round(2)}x (enriched is slower)"
      end
      {speedup: speedup, comparison: comparison}
    end
  end
end
