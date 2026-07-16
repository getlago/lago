# frozen_string_literal: true

module Types
  module Integrations
    class Xero
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateXeroIntegrationInput"

        argument :code, String, required: true
        argument :name, String, required: true

        argument :connection_id, String, required: true

        argument :sync_credit_notes, Boolean, required: false
        argument :sync_invoices, Boolean, required: false
        argument :sync_payments, Boolean, required: false
      end
    end
  end
end
