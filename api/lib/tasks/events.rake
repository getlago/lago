# frozen_string_literal: true

namespace :events do
  # NOTE: related to https://github.com/getlago/lago-api/issues/317
  desc "Fill missing timestamps for events"
  task fill_timestamp: :environment do
    Event.unscoped.where(timestamp: nil).find_each do |event|
      event.update!(timestamp: event.created_at)
    end
  end

  desc "Fill missing subscription_id"
  task fill_subscription: :environment do
    Event.unscoped.where(subscription_id: nil).find_each do |event|
      subscription = event.customer.active_subscription || event.customer.subscriptions.order(:created_at).last

      unless subscription
        event.destroy
        next
      end

      event.update!(subscription_id: subscription.id)
    end
  end

  desc "Deduplicate events_enriched_expanded by removing older versions of duplicate rows"
  task deduplicate_enriched_expanded: :environment do
    Rails.logger.level = Logger::Severity::INFO

    organization_id = ENV.fetch("ORGANIZATION_ID")
    subscription_ids = ENV["SUBSCRIPTION_IDS"].to_s.split(",").map(&:strip).reject(&:blank?)
    codes = ENV["BM_CODES"].to_s.split(",").map(&:strip).reject(&:blank?)
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    quiet = ENV.fetch("QUIET", "false") == "true"
    timeout = ENV["TIMEOUT"].presence

    organization = Organization.find(organization_id)
    subscriptions = organization.subscriptions
    subscriptions = subscriptions.where(id: subscription_ids) if subscription_ids.present?

    total_duplicates = 0

    subscriptions.find_each do |subscription|
      service = Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService.new(subscription:, codes:, timeout: timeout.to_i.positive? ? timeout.to_i : nil)

      duplicate_count = service.count_duplicates

      if dry_run
        if duplicate_count > 0 || !quiet
          Rails.logger.info(
            "events:deduplicate_enriched_expanded [DRY RUN] - Subscription #{subscription.external_id}: #{duplicate_count} duplicate rows would be removed"
          )
        end
      else
        begin
          result = service.call
          duplicate_count = result.duplicated_count

          if duplicate_count > 0 || !quiet
            message = "duplicate rows will be removed"
            message = "#{duplicate_count} have to be removed" if result.queries.present?

            Rails.logger.info(
              "events:deduplicate_enriched_expanded - Subscription #{subscription.external_id}: #{duplicate_count} #{message}"
            )
          end

          if result.queries.present?
            Rails.logger.warn(
              "events:deduplicate_enriched_expanded - Subscription #{subscription.external_id}: " \
              "#{result.queries.size} batch(es) timed out. Run manually:"
            )
            result.queries.each { |q| Rails.logger.warn(q) }
          end
        rescue => e
          duplicate_count = 0
          Rails.logger.error("events:deduplicate_enriched_expanded - Subscription #{subscription.external_id}: Error removing duplicates: #{e.message}")
        end
      end

      total_duplicates += duplicate_count
    end

    mode = dry_run ? "DRY RUN" : "LIVE"
    action = dry_run ? "found" : "removed"
    Rails.logger.info("events:deduplicate_enriched_expanded [#{mode}] - Complete. #{total_duplicates} total duplicate rows #{action}.")
  end

  desc "Detect and optionally reprocess events for subscriptions needing re-enrichment"
  task reprocess: :environment do
    Rails.logger.level = Logger::Severity::INFO

    organization_id = ENV.fetch("ORGANIZATION_ID")
    reprocess = ENV.fetch("REPROCESS", "false") == "true"
    batch_size = (ENV["BATCH_SIZE"] || 1000).to_i
    sleep_seconds = (ENV["SLEEP_SECONDS"] || 0.5).to_f

    organization = Organization.find(organization_id)

    service_result = Events::Stores::Clickhouse::PreEnrichmentCheckService.call(
      organization:, reprocess:, batch_size:, sleep_seconds:
    )

    subscriptions_map = service_result.subscriptions_to_reprocess
    mode = reprocess ? "REPROCESS" : "DRY RUN"

    if subscriptions_map.empty?
      Rails.logger.info("events:reprocess [#{mode}] - No subscriptions need reprocessing")
    else
      subscriptions_map.each do |sub_id, codes|
        Rails.logger.info("events:reprocess [#{mode}] - Subscription #{sub_id}: #{codes.join(", ")}")
      end
      Rails.logger.info("events:reprocess [#{mode}] - #{subscriptions_map.size} subscriptions detected")
    end
  ensure
    Karafka.producer.close if reprocess
  end
end
