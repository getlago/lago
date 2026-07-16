# frozen_string_literal: true

class AppliedUsageThreshold < ApplicationRecord
  belongs_to :usage_threshold, -> { with_discarded }
  belongs_to :invoice
  belongs_to :organization

  validates :usage_threshold_id, uniqueness: {scope: :invoice_id}

  monetize :lifetime_usage_amount_cents,
    with_currency: ->(applied_usage_threshold) { applied_usage_threshold.invoice.currency }

  monetize :passed_threshold_amount_cents,
    disable_validation: true,
    with_currency: ->(applied_usage_threshold) { applied_usage_threshold.invoice.currency }

  def passed_threshold_amount_cents
    if usage_threshold.recurring?
      lifetime_usage_amount_cents - (lifetime_usage_amount_cents % usage_threshold.amount_cents)
    else
      usage_threshold.amount_cents
    end
  end
end

# == Schema Information
#
# Table name: applied_usage_thresholds
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  lifetime_usage_amount_cents :bigint           default(0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  invoice_id                  :uuid             not null
#  organization_id             :uuid             not null
#  usage_threshold_id          :uuid             not null
#
# Indexes
#
#  idx_on_usage_threshold_id_invoice_id_cb82cdf163       (usage_threshold_id,invoice_id) UNIQUE
#  index_applied_usage_thresholds_on_invoice_id          (invoice_id)
#  index_applied_usage_thresholds_on_organization_id     (organization_id)
#  index_applied_usage_thresholds_on_usage_threshold_id  (usage_threshold_id)
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (usage_threshold_id => usage_thresholds.id)
#
