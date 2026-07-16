# frozen_string_literal: true

class AddForeignKeyOnBillingEntitiesAppliedDunningCampaignId < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :billing_entities, :dunning_campaigns, column: :applied_dunning_campaign_id, on_delete: :nullify, validate: false
  end
end
