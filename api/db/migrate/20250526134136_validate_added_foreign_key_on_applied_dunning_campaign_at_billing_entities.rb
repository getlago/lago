# frozen_string_literal: true

class ValidateAddedForeignKeyOnAppliedDunningCampaignAtBillingEntities < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :billing_entities, :dunning_campaigns, column: :applied_dunning_campaign_id
  end
end
