# frozen_string_literal: true

class Group < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :billable_metric, -> { with_discarded }
  belongs_to :parent, -> { with_discarded }, class_name: "Group", foreign_key: "parent_group_id", optional: true
  has_many :children, class_name: "Group", foreign_key: "parent_group_id"
  has_many :properties, class_name: "GroupProperty"
  has_many :fees

  validates :key, :value, presence: true

  default_scope -> { kept }
  scope :parents, -> { where(parent_group_id: nil) }
  scope :children, -> { where.not(parent_group_id: nil) }

  def name
    parent ? "#{parent.value} • #{value}" : value
  end

  # NOTE: Discard group and children with properties.
  def discard_with_properties!
    children.each { |c| c.properties&.update_all(deleted_at: Time.current) && c.discard! } && properties.update_all(deleted_at: Time.current) && discard! # rubocop:disable Rails/SkipsModelValidations
  end
end

# == Schema Information
#
# Table name: groups
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  deleted_at         :datetime
#  key                :string           not null
#  value              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  billable_metric_id :uuid             not null
#  parent_group_id    :uuid
#
# Indexes
#
#  index_groups_on_billable_metric_id                      (billable_metric_id)
#  index_groups_on_billable_metric_id_and_parent_group_id  (billable_metric_id,parent_group_id)
#  index_groups_on_deleted_at                              (deleted_at)
#  index_groups_on_parent_group_id                         (parent_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id) ON DELETE => cascade
#  fk_rails_...  (parent_group_id => groups.id)
#
