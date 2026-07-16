# frozen_string_literal: true

class LifetimeUsage < ApplicationRecord
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  belongs_to :subscription

  validates :current_usage_amount_cents, numericality: {greater_than_or_equal_to: 0}
  validates :invoiced_usage_amount_cents, numericality: {greater_than_or_equal_to: 0}
  validates :historical_usage_amount_cents, numericality: {greater_than_or_equal_to: 0}

  monetize :current_usage_amount_cents,
    :invoiced_usage_amount_cents,
    :historical_usage_amount_cents,
    with_currency: ->(lifetime_usage) { lifetime_usage.subscription.plan.amount_currency }

  default_scope -> { kept }

  def total_amount_cents
    historical_usage_amount_cents + invoiced_usage_amount_cents + current_usage_amount_cents
  end
end

# == Schema Information
#
# Table name: lifetime_usages
# Database name: primary
#
#  id                                 :uuid             not null, primary key
#  current_usage_amount_cents         :bigint           default(0), not null
#  current_usage_amount_refreshed_at  :datetime
#  deleted_at                         :datetime
#  historical_usage_amount_cents      :bigint           default(0), not null
#  invoiced_usage_amount_cents        :bigint           default(0), not null
#  invoiced_usage_amount_refreshed_at :datetime
#  recalculate_current_usage          :boolean          default(FALSE), not null
#  recalculate_invoiced_usage         :boolean          default(FALSE), not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  organization_id                    :uuid             not null
#  subscription_id                    :uuid             not null
#
# Indexes
#
#  index_lifetime_usages_on_organization_id             (organization_id)
#  index_lifetime_usages_on_recalculate_current_usage   (recalculate_current_usage) WHERE ((deleted_at IS NULL) AND (recalculate_current_usage = true))
#  index_lifetime_usages_on_recalculate_invoiced_usage  (recalculate_invoiced_usage) WHERE ((deleted_at IS NULL) AND (recalculate_invoiced_usage = true))
#  index_lifetime_usages_on_subscription_id             (subscription_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
