# frozen_string_literal: true

class NotNullOrganizationIdOnDunningCampaignThresholds < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :dunning_campaign_thresholds, name: "dunning_campaign_thresholds_organization_id_null"
    change_column_null :dunning_campaign_thresholds, :organization_id, false
    remove_check_constraint :dunning_campaign_thresholds, name: "dunning_campaign_thresholds_organization_id_null"
  end

  def down
    add_check_constraint :dunning_campaign_thresholds, "organization_id IS NOT NULL", name: "dunning_campaign_thresholds_organization_id_null", validate: false
    change_column_null :dunning_campaign_thresholds, :organization_id, true
  end
end
