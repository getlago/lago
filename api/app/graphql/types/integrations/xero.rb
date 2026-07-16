# frozen_string_literal: true

module Types
  module Integrations
    class Xero < Types::BaseObject
      graphql_name "XeroIntegration"

      field :code, String, null: false
      field :connection_id, ID, null: false
      field :has_mappings_configured, Boolean
      field :id, ID, null: false
      field :name, String, null: false
      field :sync_credit_notes, Boolean
      field :sync_invoices, Boolean
      field :sync_payments, Boolean

      def has_mappings_configured
        object.integration_collection_mappings.where(type: "IntegrationCollectionMappings::XeroCollectionMapping").any?
      end
    end
  end
end
