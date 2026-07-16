# frozen_string_literal: true

require_relative "../../task_prompt"

namespace :recipes do
  namespace :clickhouse do
    desc "Check if an organization can be safely migrated to ClickHouse events store, and enable it if possible"
    task enable_clickhouse_events_store: :environment do
      Rails.logger.level = Logger::Severity::ERROR

      usage_comparison_sample_window = 30.days

      organization = TaskPrompt.ask_for_organization
      abort "The organization is already using ClickHouse events store." if organization.clickhouse_events_store?

      active_subscriptions_count = Subscription.active.where(organization_id: organization.id).count
      puts "Organization has #{active_subscriptions_count} active subscription(s)."
      sample_size_input = TaskPrompt.ask("Number of subscriptions to sample for usage comparison [default: 100]: ")
      usage_comparison_sample_size = sample_size_input.empty? ? 100 : sample_size_input.to_i

      puts "Step 1: Compare the number of events in Postgres and ClickHouse"
      max_age = Time.current.beginning_of_hour

      sub_ids = Event.where(organization_id: organization.id).select("DISTINCT(external_subscription_id)")
      postgres_count = Event.with_discarded
        .where(organization_id: organization.id)
        .where(external_subscription_id: sub_ids)
        .where(timestamp: ..max_age)
        .count

      deduped_events = Clickhouse::EventsEnriched
        .where(organization_id: organization.id)
        .where(timestamp: ..max_age)
        .group(:transaction_id, :timestamp, :code, :external_subscription_id)
        .select(:transaction_id, :timestamp, :code, :external_subscription_id)

      clickhouse_count = Clickhouse::EventsEnriched
        .with(deduped_events:)
        .from("deduped_events")
        .count

      puts "Postgres count: #{postgres_count}, ClickHouse count: #{clickhouse_count}"
      abort "The number of events in Postgres and ClickHouse does not match." unless postgres_count == clickhouse_count

      puts "Step 2: Check for events with enrichment issues"
      value_issues_count = Clickhouse::EventsEnriched.where(organization_id: organization.id)
        .where(value: "<nil>")
        .count
      abort "There are #{value_issues_count} events with enrichment issues. Please fix them before proceeding." if value_issues_count > 0

      puts "Step 3: Compare usage on Postgres vs ClickHouse for top #{usage_comparison_sample_size} subscriptions"
      top_external_ids = Clickhouse::EventsEnriched
        .where(organization_id: organization.id, timestamp: usage_comparison_sample_window.ago..)
        .group(:external_subscription_id)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(usage_comparison_sample_size)
        .count
        .keys

      sampled_subscriptions = top_external_ids.filter_map do |external_id|
        Subscription.where(organization_id: organization.id, external_id:, status: :active).first
      end

      if sampled_subscriptions.empty?
        puts "  No active subscriptions with recent events found, skipping usage comparison."
      else
        diffs = []

        sampled_subscriptions.each do |subscription|
          legacy_total, enriched_total, legacy_fees, enriched_fees =
            compute_usage_totals(subscription)

          if legacy_total != enriched_total && recent_events?(organization, subscription)
            puts "  Subscription #{subscription.id}: detected events received in last minute, waiting before retry..."
            Kernel.sleep 5
            legacy_total, enriched_total, legacy_fees, enriched_fees =
              compute_usage_totals(subscription)
          end

          status = (legacy_total == enriched_total) ? "OK" : "DIFF"
          puts "  Subscription #{subscription.id}: PG=#{legacy_total} CH=#{enriched_total} [#{status}]"

          if legacy_total != enriched_total
            diffs << {subscription:, legacy_total:, enriched_total:, legacy_fees:, enriched_fees:}
          end
        end

        if diffs.any?
          puts ""
          puts "Usage mismatch detected on #{diffs.size} subscription(s):"
          diffs.each do |d|
            puts "  - Subscription #{d[:subscription].id} (external_id=#{d[:subscription].external_id})"
            puts "      PG total:  #{d[:legacy_total]} (#{d[:legacy_fees].size} fees)"
            puts "      CH total:  #{d[:enriched_total]} (#{d[:enriched_fees].size} fees)"
            puts "      Diff:      #{d[:legacy_total] - d[:enriched_total]}"
          end
          abort "Total amount mismatch detected. Investigate before enabling ClickHouse events store."
        end
      end

      puts "Step 4: Enabling ClickHouse events store for the organization"
      puts ""
      puts "  /!\\ Before confirming, verify manually that the organization is NOT in the middle"
      puts "      of an ingestion burst. Follow the 'Migrating' section of the runbook:"
      puts "      https://www.notion.so/getlago/Migration-an-organization-from-Postgres-to-Clickhouse-2f8ef63110d28004bbdadda69c4b2630"
      puts "      Confirming below acknowledges this check has been performed."
      puts ""
      TaskPrompt.confirm!("Do you want to proceed? (y/n): ")
      organization.update!(clickhouse_events_store: true, clickhouse_deduplication_enabled: true)
      ApiKeys::CacheService.expire_all_cache(organization)

      puts "DONE."
    end
  end
end

def compute_usage_totals(subscription)
  legacy_result = Invoices::CustomerUsageService.call(
    customer: subscription.customer,
    subscription:,
    with_cache: true,
    apply_taxes: false
  )
  legacy_fees = legacy_result.usage&.fees || []

  enriched_result = Events::Stores::StoreFactory.with_override(
    store_class: Events::Stores::ClickhouseStore,
    deduplicate: true
  ) do
    Invoices::CustomerUsageService.call(
      customer: subscription.customer,
      subscription:,
      with_cache: false,
      apply_taxes: false
    )
  end
  enriched_fees = enriched_result.usage&.fees || []

  [legacy_fees.sum(&:amount_cents), enriched_fees.sum(&:amount_cents), legacy_fees, enriched_fees]
end

def recent_events?(organization, subscription)
  Event
    .where(organization_id: organization.id, external_subscription_id: subscription.external_id)
    .where(timestamp: 1.minute.ago..)
    .exists?
end
