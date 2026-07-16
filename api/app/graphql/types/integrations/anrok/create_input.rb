# frozen_string_literal: true

module Types
  module Integrations
    class Anrok
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateAnrokIntegrationInput"

        argument :code, String, required: true
        argument :name, String, required: true

        argument :api_key, String, required: true
        argument :connection_id, String, required: true
      end
    end
  end
end
