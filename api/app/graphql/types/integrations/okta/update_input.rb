# frozen_string_literal: true

module Types
  module Integrations
    class Okta
      class UpdateInput < Types::BaseInputObject
        graphql_name "UpdateOktaIntegrationInput"

        argument :id, ID, required: false

        argument :client_id, String, required: false
        argument :client_secret, String, required: false
        argument :domain, String, required: false
        argument :host, String, required: false
        argument :organization_name, String, required: false
      end
    end
  end
end
