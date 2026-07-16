# frozen_string_literal: true

require_relative "../../task_prompt"

BATCH_SIZE = 2000

# rubocop:disable Rails/Output,Rails/Exit
namespace :recipes do
  namespace :events do
    desc "Soft-delete PG events for an organization within a time range"
    task delete_in_range: :environment do
      organization = TaskPrompt.ask_for_organization
      abort "This task only supports organizations using PostgreSQL events store." unless organization.postgres_events_store?

      from_time, to_time = TaskPrompt.ask_for_timestamp_range

      subscriptions = organization.subscriptions.distinct.pluck(:external_id)

      if subscriptions.empty?
        puts "No subscriptions found for this organization."
        next
      end

      puts "Found #{subscriptions.size} distinct subscriptions."

      puts "\nThis will soft-delete events from \"#{organization.name}\" " \
        "from #{from_time.utc} to #{to_time.utc} (inclusive)."
      TaskPrompt.confirm!("Continue? (y/n): ")

      total_deleted = 0

      # rubocop:disable Rails/SkipsModelValidations
      subscriptions.each_with_index do |external_id, index|
        events = Event.where(
          organization_id: organization.id,
          external_subscription_id: external_id
        ).from_datetime(from_time).to_datetime(to_time)

        sub_deleted = 0
        prefix = "[#{index + 1}/#{subscriptions.size}]"

        events.in_batches(of: BATCH_SIZE) do |batch|
          sub_deleted += batch.update_all(deleted_at: Time.current)
          print "\r\e[K#{prefix} Subscription #{external_id}: #{sub_deleted} events deleted. Total: #{total_deleted + sub_deleted}"
        end

        if sub_deleted.zero?
          print "\r\e[K#{prefix} Subscription #{external_id}: no events, skipped."
        end

        total_deleted += sub_deleted
      end
      # rubocop:enable Rails/SkipsModelValidations

      if total_deleted.zero?
        puts "No events found in the given time range. Nothing to delete."
        next
      end

      puts "\nDone. #{total_deleted} events soft-deleted across #{subscriptions.size} subscriptions."
    end
  end
end
# rubocop:enable Rails/Output,Rails/Exit
