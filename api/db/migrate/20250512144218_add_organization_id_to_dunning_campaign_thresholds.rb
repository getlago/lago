# frozen_string_literal: true

class AddOrganizationIdToDunningCampaignThresholds < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :dunning_campaign_thresholds, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
