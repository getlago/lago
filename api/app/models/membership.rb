# frozen_string_literal: true

class Membership < ApplicationRecord
  include PaperTrailTraceable

  belongs_to :organization
  belongs_to :user

  has_many :data_exports
  has_many :membership_roles
  has_many :roles, through: :membership_roles

  STATUSES = [
    :active,
    :revoked
  ].freeze

  enum :status, STATUSES

  validates :user_id, uniqueness: {conditions: -> { where(revoked_at: nil) }, scope: :organization_id}

  scope :admins, -> { joins(:roles).where(roles: {admin: true}).distinct }

  def admin?
    roles.admins.exists?
  end

  def mark_as_revoked!(timestamp = Time.current)
    self.revoked_at ||= timestamp
    revoked!
  end

  def can?(permission)
    permissions_hash[permission.to_s]
  end

  def permissions_hash
    Permission.permissions_hash.dup.tap do |h|
      roles.each { |role| role.permissions_hash.each { |key, val| h[key] ||= val } }
    end
  end
end

# == Schema Information
#
# Table name: memberships
# Database name: primary
#
#  id              :uuid             not null, primary key
#  revoked_at      :datetime
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_memberships_by_id_and_organization          (id,organization_id) UNIQUE
#  index_memberships_on_organization_id              (organization_id)
#  index_memberships_on_user_id                      (user_id)
#  index_memberships_on_user_id_and_organization_id  (user_id,organization_id) UNIQUE WHERE (revoked_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
