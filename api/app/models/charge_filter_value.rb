# frozen_string_literal: true

class ChargeFilterValue < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  ALL_FILTER_VALUES = "__ALL_FILTER_VALUES__"

  belongs_to :charge_filter, -> { with_discarded }
  belongs_to :billable_metric_filter, -> { with_discarded }
  belongs_to :organization

  validates :values, presence: true
  validate :validate_values

  # NOTE: Ensure filters are keeping the initial ordering
  default_scope -> { kept.order(updated_at: :asc) }

  delegate :key, to: :billable_metric_filter

  private

  def validate_values
    unless values.nil?
      return if values.count == 1 && values.first == ALL_FILTER_VALUES
      return if values.all? { billable_metric_filter&.values&.include?(it) } # rubocop:disable Performance/InefficientHashSearch
    end

    errors.add(:values, :inclusion)
  end
end

# == Schema Information
#
# Table name: charge_filter_values
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  deleted_at                :datetime
#  values                    :string           default([]), not null, is an Array
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  billable_metric_filter_id :uuid             not null
#  charge_filter_id          :uuid             not null
#  organization_id           :uuid             not null
#
# Indexes
#
#  index_active_charge_filter_values                        (charge_filter_id) WHERE (deleted_at IS NULL)
#  index_charge_filter_values_on_billable_metric_filter_id  (billable_metric_filter_id)
#  index_charge_filter_values_on_charge_filter_id           (charge_filter_id)
#  index_charge_filter_values_on_deleted_at                 (deleted_at)
#  index_charge_filter_values_on_organization_id            (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_filter_id => billable_metric_filters.id)
#  fk_rails_...  (charge_filter_id => charge_filters.id)
#  fk_rails_...  (organization_id => organizations.id)
#
