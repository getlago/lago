# frozen_string_literal: true

class AddOrganizationIdFkToDunningCampaignThresholds < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :dunning_campaign_thresholds, :organizations, validate: false
  end
end
