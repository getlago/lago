# frozen_string_literal: true

class BillableMetricFilter < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :billable_metric, -> { with_discarded }
  belongs_to :organization

  has_many :filter_values, class_name: "ChargeFilterValue", dependent: :destroy
  has_many :charge_filters, through: :filter_values

  validates :key, presence: true
  validates :values, presence: true

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: billable_metric_filters
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  deleted_at         :datetime
#  key                :string           not null
#  values             :string           default([]), not null, is an Array
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  billable_metric_id :uuid             not null
#  organization_id    :uuid             not null
#
# Indexes
#
#  index_active_metric_filters                          (billable_metric_id) WHERE (deleted_at IS NULL)
#  index_billable_metric_filters_on_billable_metric_id  (billable_metric_id)
#  index_billable_metric_filters_on_deleted_at          (deleted_at)
#  index_billable_metric_filters_on_organization_id     (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id)
#  fk_rails_...  (organization_id => organizations.id)
#
