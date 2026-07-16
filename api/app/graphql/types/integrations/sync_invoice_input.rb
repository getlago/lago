# frozen_string_literal: true

module Types
  module Integrations
    class SyncInvoiceInput < Types::BaseInputObject
      graphql_name "SyncIntegrationInvoiceInput"

      argument :invoice_id, ID, required: true
    end
  end
end
