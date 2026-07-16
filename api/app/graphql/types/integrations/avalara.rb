# frozen_string_literal: true

module Types
  module Integrations
    class Avalara < Types::BaseObject
      graphql_name "AvalaraIntegration"

      field :account_id, String, null: true
      field :code, String, null: false
      field :company_code, String, null: false
      field :company_id, String, null: true
      field :failed_invoices_count, Integer, null: true
      field :has_mappings_configured, Boolean
      field :id, ID, null: false
      field :license_key, ObfuscatedStringType, null: false
      field :name, String, null: false

      def has_mappings_configured
        object.integration_collection_mappings.where(type: "IntegrationCollectionMappings::AvalaraCollectionMapping").any?
      end

      def failed_invoices_count
        object.organization.failed_tax_invoices_count
      end
    end
  end
end
