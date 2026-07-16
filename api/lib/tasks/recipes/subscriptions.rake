# frozen_string_literal: true

require_relative "../../task_prompt"

# rubocop:disable Rails/Output,Rails/Exit
namespace :recipes do
  namespace :subscriptions do
    desc "Terminate active subscriptions and cancel pending subscriptions for an organization"
    task terminate_all: :environment do
      organization = TaskPrompt.ask_for_organization

      active_count = organization.subscriptions.active.count
      pending_count = organization.subscriptions.pending.count

      if active_count.zero? && pending_count.zero?
        puts "No active or pending subscriptions for #{organization.name}."
        next
      end

      puts ""
      puts "Found #{active_count} active and #{pending_count} pending subscription(s) for #{organization.name}."
      puts "This will:"
      puts "  - Terminate active subscriptions synchronously (final invoices/credit-notes per each sub's settings)"
      puts "  - Cancel pending subscriptions"
      puts "  - Emit `subscription.terminated` webhooks for each subscription"
      TaskPrompt.confirm!("Continue? (y/n): ")

      total = active_count + pending_count
      processed = 0

      organization.subscriptions.active.find_each do |subscription|
        processed += 1
        prefix = "[#{processed}/#{total}]"

        result = Subscriptions::TerminateService.call(subscription:, async: false)
        if result.failure?
          abort "#{prefix} Failed to terminate subscription #{subscription.id}: #{result.error}"
        end

        puts "#{prefix} Terminated #{subscription.id} (was active)"
      end

      organization.subscriptions.pending.find_each do |subscription|
        processed += 1
        prefix = "[#{processed}/#{total}]"

        result = Subscriptions::TerminateService.call(subscription:, async: false)
        if result.failure?
          abort "#{prefix} Failed to cancel subscription #{subscription.id}: #{result.error}"
        end

        puts "#{prefix} Canceled #{subscription.id} (was pending)"
      end

      puts ""
      puts "Done. #{active_count} terminated, #{pending_count} canceled."
    end
  end
end
# rubocop:enable Rails/Output,Rails/Exit
