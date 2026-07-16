# frozen_string_literal: true

module Types
  module Integrations
    class Anrok
      class UpdateInput < Types::BaseInputObject
        graphql_name "UpdateAnrokIntegrationInput"

        argument :id, ID, required: false

        argument :code, String, required: false
        argument :name, String, required: false

        argument :api_key, String, required: false
      end
    end
  end
end
