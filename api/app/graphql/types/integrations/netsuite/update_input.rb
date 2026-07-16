# frozen_string_literal: true

module Types
  module Integrations
    class Netsuite
      class UpdateInput < Types::BaseInputObject
        graphql_name "UpdateNetsuiteIntegrationInput"

        argument :id, ID, required: false

        argument :code, String, required: false
        argument :name, String, required: false

        argument :account_id, String, required: false
        argument :client_id, String, required: false
        argument :client_secret, String, required: false
        argument :connection_id, String, required: false
        argument :script_endpoint_url, String, required: false
        argument :token_id, String, required: false
        argument :token_secret, String, required: false

        argument :sync_credit_notes, Boolean, required: false
        argument :sync_invoices, Boolean, required: false
        argument :sync_payments, Boolean, required: false
      end
    end
  end
end
