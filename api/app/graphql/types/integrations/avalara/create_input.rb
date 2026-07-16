# frozen_string_literal: true

module Types
  module Integrations
    class Avalara
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateAvalaraIntegrationInput"

        argument :code, String, required: true
        argument :name, String, required: true

        argument :account_id, String, required: true
        argument :company_code, String, required: true
        argument :connection_id, String, required: true
        argument :license_key, String, required: true
      end
    end
  end
end
