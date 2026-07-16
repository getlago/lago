# frozen_string_literal: true

class PopulateBillingEntityAppliedDunningCampaign < ActiveRecord::Migration[8.0]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def up
    # rubocop:disable Rails/SkipsModelValidations
    DunningCampaign.where(applied_to_organization: true).find_each do |dunning_campaign|
      BillingEntity.where(id: dunning_campaign.organization_id).update_all(applied_dunning_campaign_id: dunning_campaign.id)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
  end
end
