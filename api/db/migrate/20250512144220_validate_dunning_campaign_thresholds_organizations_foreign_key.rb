# frozen_string_literal: true

class ValidateDunningCampaignThresholdsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :dunning_campaign_thresholds, :organizations
  end
end
