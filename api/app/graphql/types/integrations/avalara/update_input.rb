# frozen_string_literal: true

module Types
  module Integrations
    class Avalara
      class UpdateInput < Types::BaseInputObject
        graphql_name "UpdateAvalaraIntegrationInput"

        argument :id, ID, required: false

        argument :code, String, required: false
        argument :company_code, String, required: false
        argument :name, String, required: false

        argument :account_id, String, required: false
        argument :license_key, String, required: false
      end
    end
  end
end
