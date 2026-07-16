# frozen_string_literal: true

class ChargeFilter < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model
  include ChargePropertiesValidation

  self.discard_column = :deleted_at

  belongs_to :charge, -> { with_discarded }, touch: true
  belongs_to :organization

  has_many :values, class_name: "ChargeFilterValue", dependent: :destroy
  has_many :billable_metric_filters, through: :values
  has_many :fees

  has_one :billable_metric, through: :charge

  validate :validate_properties

  # NOTE: Ensure filters are keeping the initial ordering
  default_scope -> { kept.order(updated_at: :asc) }

  def display_name(separator: ", ")
    invoice_display_name.presence || (values.map do |value|
      next value.billable_metric_filter.key if value.values == [ChargeFilterValue::ALL_FILTER_VALUES]

      value.values
    end).flatten.join(separator)
  end

  def to_h
    @to_h ||= values.each_with_object({}) do |filter_value, result|
      result[filter_value.billable_metric_filter.key] = filter_value.values
    end.freeze
  end

  def to_h_with_discarded
    @to_h_with_discarded ||= values.with_discarded.each_with_object({}) do |filter_value, result|
      result[filter_value.billable_metric_filter.key] = filter_value.values
    end.freeze
  end

  def to_h_with_all_values
    @to_h_with_all_values ||= values.each_with_object({}) do |filter_value, result|
      values = filter_value.values
      values = filter_value.billable_metric_filter.values if values == [ChargeFilterValue::ALL_FILTER_VALUES]

      result[filter_value.billable_metric_filter.key] = values
    end.freeze
  end

  def pricing_group_keys
    properties["pricing_group_keys"].presence || properties["grouped_by"]
  end

  private

  def validate_properties
    validate_charge_model_properties(charge&.charge_model)
  end
end

# == Schema Information
#
# Table name: charge_filters
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  deleted_at           :datetime
#  invoice_display_name :string
#  properties           :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  charge_id            :uuid             not null
#  organization_id      :uuid             not null
#
# Indexes
#
#  index_active_charge_filters              (charge_id) WHERE (deleted_at IS NULL)
#  index_charge_filters_on_charge_id        (charge_id)
#  index_charge_filters_on_deleted_at       (deleted_at)
#  index_charge_filters_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (organization_id => organizations.id)
#
