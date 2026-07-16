# frozen_string_literal: true

module Types
  module Integrations
    class Anrok < Types::BaseObject
      graphql_name "AnrokIntegration"

      field :api_key, ObfuscatedStringType, null: false
      field :code, String, null: false
      field :external_account_id, String, null: true
      field :failed_invoices_count, Integer, null: true
      field :has_mappings_configured, Boolean
      field :id, ID, null: false
      field :name, String, null: false

      def has_mappings_configured
        object.integration_collection_mappings.where(type: "IntegrationCollectionMappings::AnrokCollectionMapping").any?
      end

      def external_account_id
        return nil unless object.api_key.include?("/")

        object.api_key.split("/")[0]
      end

      def failed_invoices_count
        object.organization.failed_tax_invoices_count
      end
    end
  end
end
