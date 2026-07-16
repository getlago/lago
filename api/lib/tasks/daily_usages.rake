# frozen_string_literal: true

require_relative "../task_prompt"

# rubocop:disable Rails/Output,Rails/Exit
namespace :daily_usages do
  desc "Fill past daily usage"
  task fill_history: :environment do
    Rails.logger.level = Logger::INFO

    deletion_batch_size = 10_000

    organization = TaskPrompt.ask_for_organization

    subscription_ids = TaskPrompt.ask_for_subscription_ids

    default_from_date = DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date
    from_date = TaskPrompt.ask_for_date("From date (YYYY-MM-DD)", default: default_from_date)

    subscriptions = organization.subscriptions
      .where(status: [:active, :terminated])
      .where.not(started_at: nil)
      .where("terminated_at IS NULL OR terminated_at >= ?", from_date)
      .includes(customer: :organization)
    subscriptions = subscriptions.where(id: subscription_ids) if subscription_ids.present?

    # ----- recon (read-only) -----
    sub_count = subscriptions.count
    daily_usages = DailyUsage
      .where(organization_id: organization.id)
      .where("usage_date >= ?", from_date)
      .where(subscription_id: subscriptions.select(:id))
    daily_usages_count = daily_usages.count

    days = (Date.current - from_date).to_i + 1

    puts ""
    puts "----- recon -----"
    puts "organization          : #{organization.name} (#{organization.id})"
    puts "requested subs        : #{subscription_ids.present? ? subscription_ids.size : "all"}"
    puts "subs in scope         : #{sub_count}"
    puts "existing daily_usages : #{daily_usages_count}"
    puts "days in backfill range: #{days} (#{from_date} .. #{Date.current})"
    puts "-----------------"

    if sub_count.zero?
      puts "No subscriptions in scope. Nothing to do."
      next
    end

    delete_existing = daily_usages_count.positive? &&
      TaskPrompt.confirm?("Delete the #{daily_usages_count} existing daily_usages above? (y/n): ")

    puts ""
    puts "This will:"
    puts "  - Delete the #{daily_usages_count} existing daily_usages above" if delete_existing
    puts "  - Enqueue a FillHistoryJob for each of the #{sub_count} subscriptions"
    TaskPrompt.confirm!("Continue? (y/n): ")

    # ----- delete existing daily_usages in batches -----
    if delete_existing
      puts ""
      puts "Deleting existing daily_usages..."
      delete_start = Time.current
      deleted_total = 0

      daily_usages.in_batches(of: deletion_batch_size) do |batch|
        deleted_total += batch.delete_all
      end
      puts "deleted #{deleted_total} rows in #{(Time.current - delete_start).round}s"
    end

    # ----- enqueue FillHistoryJob -----
    puts ""
    puts "Enqueueing FillHistoryJob..."
    enqueue_start = Time.current
    enqueued = 0

    subscriptions.find_each do |subscription|
      DailyUsages::FillHistoryJob.perform_later(subscription:, from_date:)
      enqueued += 1
    end

    puts "enqueued #{enqueued} jobs in #{(Time.current - enqueue_start).round}s"
  end
end
# rubocop:enable Rails/Output,Rails/Exit
