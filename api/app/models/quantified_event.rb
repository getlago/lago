# frozen_string_literal: true

class QuantifiedEvent < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  RECURRING_TOTAL_UNITS = "total_aggregated_units"

  belongs_to :organization
  belongs_to :billable_metric
  belongs_to :group, optional: true

  has_many :events

  validates :added_at, presence: true
  validates :external_subscription_id, presence: true

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: quantified_events
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  added_at                 :datetime         not null
#  deleted_at               :datetime
#  grouped_by               :jsonb            not null
#  properties               :jsonb            not null
#  removed_at               :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  billable_metric_id       :uuid
#  charge_filter_id         :uuid
#  external_id              :string
#  external_subscription_id :string           not null
#  group_id                 :uuid
#  organization_id          :uuid             not null
#
# Indexes
#
#  index_quantified_events_on_billable_metric_id  (billable_metric_id)
#  index_quantified_events_on_charge_filter_id    (charge_filter_id)
#  index_quantified_events_on_deleted_at          (deleted_at)
#  index_quantified_events_on_external_id         (external_id)
#  index_quantified_events_on_group_id            (group_id)
#  index_quantified_events_on_organization_id     (organization_id)
#  index_search_quantified_events                 (organization_id,external_subscription_id,billable_metric_id)
#
# Foreign Keys
#
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (organization_id => organizations.id)
#
