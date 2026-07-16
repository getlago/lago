# frozen_string_literal: true

class GroupProperty < ApplicationRecord
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :charge
  belongs_to :group, -> { with_discarded }

  validates :values, presence: true
  validates :group_id, presence: true, uniqueness: {scope: :charge_id}

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: group_properties
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  deleted_at           :datetime
#  invoice_display_name :string
#  values               :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  charge_id            :uuid             not null
#  group_id             :uuid             not null
#
# Indexes
#
#  index_group_properties_on_charge_id               (charge_id)
#  index_group_properties_on_charge_id_and_group_id  (charge_id,group_id) UNIQUE
#  index_group_properties_on_deleted_at              (deleted_at)
#  index_group_properties_on_group_id                (group_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id) ON DELETE => cascade
#  fk_rails_...  (group_id => groups.id) ON DELETE => cascade
#
