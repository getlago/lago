# frozen_string_literal: true

module Integrations
  module Aggregator
    class SyncService < BaseService
      def action_path
        "sync/trigger"
      end

      def call
        payload = {
          provider_config_key: provider_key,
          syncs: sync_list
        }

        response = http_client.post_with_response(payload, headers)
        result.response = response

        result
      end

      private

      # NOTE: Extend it with other providers if needed
      def sync_list
        list = case integration.type
        when "Integrations::NetsuiteIntegration"
          {
            subsidiaries: "netsuite-subsidiaries-sync"
          }
        when "Integrations::XeroIntegration"
          {
            accounts: "xero-accounts-sync",
            items: "xero-items-sync",
            contacts: "xero-contacts-sync"
          }
        end

        return [list[:items]] if options[:only_items]
        return [list[:accounts]] if options[:only_accounts]

        list.values
      end
    end
  end
end
