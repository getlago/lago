# frozen_string_literal: true

module Types
  module Integrations
    class Salesforce
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateSalesforceIntegrationInput"

        argument :code, String, required: true
        argument :instance_id, String, required: true
        argument :name, String, required: true
      end
    end
  end
end
