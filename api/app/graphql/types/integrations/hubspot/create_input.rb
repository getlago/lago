# frozen_string_literal: true

module Types
  module Integrations
    class Hubspot
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateHubspotIntegrationInput"

        argument :code, String, required: true
        argument :name, String, required: true

        argument :connection_id, String, required: true
        argument :default_targeted_object, Types::Integrations::Hubspot::TargetedObjectsEnum, required: true
        argument :sync_invoices, Boolean, required: false
        argument :sync_subscriptions, Boolean, required: false
      end
    end
  end
end
