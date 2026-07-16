# frozen_string_literal: true

module Types
  module Integrations
    class Hubspot
      class UpdateInput < Types::BaseInputObject
        graphql_name "UpdateHubspotIntegrationInput"

        argument :id, ID, required: false

        argument :code, String, required: false
        argument :name, String, required: false

        argument :connection_id, String, required: false
        argument :default_targeted_object, Types::Integrations::Hubspot::TargetedObjectsEnum, required: false
        argument :sync_invoices, Boolean, required: false
        argument :sync_subscriptions, Boolean, required: false
      end
    end
  end
end
