# frozen_string_literal: true

module Types
  module DunningCampaigns
    class UpdateInput < Types::BaseInputObject
      graphql_name "UpdateDunningCampaignInput"

      argument :id, ID, required: true

      argument :applied_to_organization, Boolean, required: false
      argument :bcc_emails, [String], required: false
      argument :code, String, required: false
      argument :days_between_attempts, Integer, required: false
      argument :description, String, required: false
      argument :max_attempts, Integer, required: false
      argument :name, String, required: false
      argument :thresholds, [Types::DunningCampaignThresholds::Input], required: false
    end
  end
end
