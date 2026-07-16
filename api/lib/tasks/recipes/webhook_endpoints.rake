# frozen_string_literal: true

require_relative "../../task_prompt"

# rubocop:disable Rails/Output,Rails/Exit
namespace :recipes do
  namespace :webhook_endpoints do
    desc "Destroy all webhook endpoints for an organization"
    task destroy_all: :environment do
      organization = TaskPrompt.ask_for_organization

      endpoints = organization.webhook_endpoints.to_a

      if endpoints.empty?
        puts "No webhook endpoints found for #{organization.name}."
        next
      end

      puts ""
      puts "Found #{endpoints.size} webhook endpoint(s) for #{organization.name}:"
      endpoints.each do |endpoint|
        puts "  - #{endpoint.webhook_url} (#{endpoint.signature_algo})"
      end
      puts ""
      puts "This will hard-delete each endpoint (WebhookEndpoint is not soft-deletable)."
      puts "Pending webhooks attached to these endpoints will be deleted as well."
      TaskPrompt.confirm!("Continue? (y/n): ")

      endpoints.each_with_index do |endpoint, index|
        prefix = "[#{index + 1}/#{endpoints.size}]"

        result = WebhookEndpoints::DestroyService.call(webhook_endpoint: endpoint)
        if result.failure?
          abort "#{prefix} Failed to destroy #{endpoint.webhook_url}: #{result.error}"
        end

        puts "#{prefix} Destroyed #{endpoint.webhook_url}"
      end

      puts ""
      puts "Done. #{endpoints.size} webhook endpoint(s) destroyed."
    end
  end
end
# rubocop:enable Rails/Output,Rails/Exit
