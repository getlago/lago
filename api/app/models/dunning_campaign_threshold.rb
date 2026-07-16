# frozen_string_literal: true

class DunningCampaignThreshold < ApplicationRecord
  include Currencies
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :dunning_campaign
  belongs_to :organization

  validates :amount_cents, numericality: {greater_than_or_equal_to: 0}
  validates :currency, inclusion: {in: currency_list}
  validates :currency,
    uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :dunning_campaign_id},
    unless: :deleted_at

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: dunning_campaign_thresholds
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amount_cents        :bigint           not null
#  currency            :string           not null
#  deleted_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  dunning_campaign_id :uuid             not null
#  organization_id     :uuid             not null
#
# Indexes
#
#  idx_on_dunning_campaign_id_currency_fbf233b2ae            (dunning_campaign_id,currency) UNIQUE WHERE (deleted_at IS NULL)
#  index_dunning_campaign_thresholds_on_deleted_at           (deleted_at)
#  index_dunning_campaign_thresholds_on_dunning_campaign_id  (dunning_campaign_id)
#  index_dunning_campaign_thresholds_on_organization_id      (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (dunning_campaign_id => dunning_campaigns.id)
#  fk_rails_...  (organization_id => organizations.id)
#
