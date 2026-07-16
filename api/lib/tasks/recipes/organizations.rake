# frozen_string_literal: true

require_relative "../../task_prompt"

# rubocop:disable Rails/Output,Rails/Exit
namespace :recipes do
  namespace :organizations do
    desc "Terminate a churned organization: destroy webhook endpoints, terminate subscriptions, expire API keys"
    task terminate: :environment do
      organization = TaskPrompt.ask_for_organization

      webhook_endpoint_count = organization.webhook_endpoints.count
      active_sub_count = organization.subscriptions.active.count
      pending_sub_count = organization.subscriptions.pending.count
      api_key_count = organization.api_keys.active.count

      total = webhook_endpoint_count + active_sub_count + pending_sub_count + api_key_count
      if total.zero?
        puts "Nothing to do: no webhook endpoints, subscriptions, or active API keys for #{organization.name}."
        next
      end

      puts ""
      puts "Org churn cleanup for #{organization.name} (#{organization.id}):"
      puts "  - #{webhook_endpoint_count} webhook endpoint(s) (hard-deleted first to silence outgoing webhooks)"
      puts "  - #{active_sub_count} active subscription(s) (terminated synchronously)"
      puts "  - #{pending_sub_count} pending subscription(s) (canceled)"
      puts "  - #{api_key_count} active API key(s) (force-expired, no destroy mailer)"
      puts ""
      puts "Order: webhook endpoints → subscriptions → API keys."
      puts "This is irreversible. Aborts on the first failure."
      TaskPrompt.confirm!("Continue? (y/n): ")

      organization.webhook_endpoints.find_each.with_index(1) do |endpoint, index|
        prefix = "[webhook #{index}/#{webhook_endpoint_count}]"
        result = WebhookEndpoints::DestroyService.call(webhook_endpoint: endpoint)
        if result.failure?
          abort "#{prefix} Failed to destroy #{endpoint.webhook_url}: #{result.error}"
        end
        puts "#{prefix} Destroyed #{endpoint.webhook_url}"
      end

      organization.subscriptions.active.find_each.with_index(1) do |subscription, index|
        prefix = "[active sub #{index}/#{active_sub_count}]"
        result = Subscriptions::TerminateService.call(subscription:, async: false)
        if result.failure?
          abort "#{prefix} Failed to terminate #{subscription.id}: #{result.error}"
        end
        puts "#{prefix} Terminated #{subscription.id}"
      end

      organization.subscriptions.pending.find_each.with_index(1) do |subscription, index|
        prefix = "[pending sub #{index}/#{pending_sub_count}]"
        result = Subscriptions::TerminateService.call(subscription:, async: false)
        if result.failure?
          abort "#{prefix} Failed to cancel #{subscription.id}: #{result.error}"
        end
        puts "#{prefix} Canceled #{subscription.id}"
      end

      organization.api_keys.active.find_each.with_index(1) do |key, index|
        prefix = "[api key #{index}/#{api_key_count}]"
        result = ApiKeys::DestroyService.call(key, force: true)
        if result.failure?
          abort "#{prefix} Failed to expire #{key.name}: #{result.error}"
        end
        puts "#{prefix} Expired #{key.name} (••••#{key.value.last(4)})"
      end

      puts ""
      puts "Done. #{organization.name} cleanup complete."
    end
  end
end
# rubocop:enable Rails/Output,Rails/Exit
