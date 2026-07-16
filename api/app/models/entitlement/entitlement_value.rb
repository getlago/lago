# frozen_string_literal: true

module Entitlement
  class EntitlementValue < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at

    default_scope -> { kept }

    belongs_to :organization
    belongs_to :privilege, class_name: "Entitlement::Privilege", foreign_key: :entitlement_privilege_id
    belongs_to :entitlement, class_name: "Entitlement::Entitlement", foreign_key: :entitlement_entitlement_id

    validates :entitlement_privilege_id, presence: true
    validates :entitlement_entitlement_id, presence: true
    validates :value, presence: true
  end
end

# == Schema Information
#
# Table name: entitlement_entitlement_values
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  deleted_at                 :datetime
#  value                      :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  entitlement_entitlement_id :uuid             not null
#  entitlement_privilege_id   :uuid             not null
#  organization_id            :uuid             not null
#
# Indexes
#
#  idx_on_entitlement_entitlement_id_48c0b3356a                    (entitlement_entitlement_id)
#  idx_on_entitlement_privilege_id_6a228dc433                      (entitlement_privilege_id)
#  idx_on_entitlement_privilege_id_entitlement_entitle_9d0542eb1a  (entitlement_privilege_id,entitlement_entitlement_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_entitlement_entitlement_values_on_organization_id         (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (entitlement_entitlement_id => entitlement_entitlements.id)
#  fk_rails_...  (entitlement_privilege_id => entitlement_privileges.id)
#  fk_rails_...  (organization_id => organizations.id)
#
