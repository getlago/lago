# frozen_string_literal: true

module Integrations
  module Aggregator
    class ItemsService < BaseService
      LIMIT = 450
      MAX_SUBSEQUENT_REQUESTS = 15

      def action_path
        "v1/#{provider}/items"
      end

      def call
        @cursor = ""
        @items = []
        fetched_items = []

        ActiveRecord::Base.transaction do
          integration.integration_items.where(item_type: :standard).destroy_all

          MAX_SUBSEQUENT_REQUESTS.times do
            response = http_client.get(headers:, params:)
            fetched_items.concat(response["records"])
            @cursor = response["next_cursor"]

            break if cursor.blank?
          end

          handle_items(deduplicate_items(fetched_items))
        end

        result.items = items
        result
      end

      private

      attr_reader :cursor, :items

      def headers
        {
          "Connection-Id" => integration.connection_id,
          "Authorization" => "Bearer #{secret_key}",
          "Provider-Config-Key" => provider_key
        }
      end

      def handle_items(new_items)
        new_items.each do |item|
          integration_item = IntegrationItem.new(
            organization_id: integration.organization_id,
            integration:,
            external_id: item[integration.external_id_key],
            external_account_code: item["account_code"],
            external_name: item["name"],
            item_type: :standard
          )

          integration_item.save!

          @items << integration_item
        end
      end

      def params
        {
          limit: LIMIT
        }.merge(cursor.present? ? {cursor:} : {})
      end

      # Nango uses incremental sync to synchronize Xero items which means it doesn't not take deleted record into
      # account and therefore stores items with duplicate `item_code` (which is the external_id_key for xero items).
      # This method deduplicates items based on the `item_code` and keeps the most recently modified one based on the
      # `last_modified_at` field in `_nango_metadata`.
      #
      # Note that this will have no impact on other integrations as they rely on `id` field as `external_id_key`. So
      # if Nango uses incremental sync for those integrations, we may retrieve deleted items.
      def deduplicate_items(items)
        items
          .group_by { |item| item[integration.external_id_key] }
          .map do |_external_id, duplicates|
            duplicates.max_by { |item| item.dig("_nango_metadata", "last_modified_at") || "" }
          end
      end
    end
  end
end
