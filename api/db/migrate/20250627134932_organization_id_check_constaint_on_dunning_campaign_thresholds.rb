# frozen_string_literal: true

class OrganizationIdCheckConstaintOnDunningCampaignThresholds < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :dunning_campaign_thresholds,
      "organization_id IS NOT NULL",
      name: "dunning_campaign_thresholds_organization_id_null",
      validate: false
  end
end
