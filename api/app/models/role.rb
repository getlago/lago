# frozen_string_literal: true

class Role < ApplicationRecord
  include Discard::Model

  self.discard_column = :deleted_at
  default_scope -> { kept }

  belongs_to :organization, optional: true
  has_many :membership_roles
  has_many :memberships, through: :membership_roles
  has_many :active_memberships, -> { active }, through: :membership_roles, source: :membership

  scope :admins, -> { where(admin: true) }
  scope :with_code, ->(*codes) { where(code: codes) }
  scope :with_organization, ->(organization_id) { where(organization_id: [nil, organization_id]) }

  before_validation :normalize_name

  validate :code_is_not_reserved, if: -> { organization_id && deleted_at.blank? }
  validates :code,
    presence: true,
    length: {maximum: 100},
    format: {with: /\A[a-z0-9_]*\z/, allow_blank: true},
    uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :organization_id},
    if: -> { organization_id && deleted_at.blank? }
  validates :name,
    presence: true,
    length: {maximum: 100},
    if: -> { organization_id && deleted_at.blank? }
  validates :description, length: {maximum: 255}
  validates :permissions, presence: true, if: :organization_id

  def permissions_hash
    Permission.permissions_hash(name).dup.tap do |h|
      permissions.each { |key| h[key] = true if h.key?(key) }
    end
  end

  private

  RESERVED_CODES = %w[admin finance manager].freeze

  def normalize_name
    self.name = name&.strip&.gsub(/\s+/, " ")
  end

  def code_is_not_reserved
    errors.add(:code, :taken) if RESERVED_CODES.include?(code)
  end
end

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id              :uuid             not null, primary key
#  admin           :boolean          default(FALSE), not null
#  code            :string           not null
#  deleted_at      :datetime
#  description     :string
#  name            :string           not null
#  permissions     :string           default([]), not null, is an Array
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid
#
# Indexes
#
#  index_roles_by_code_per_organization  (organization_id NULLS FIRST,code) UNIQUE WHERE (deleted_at IS NULL)
#  index_roles_by_unique_admin           (admin) UNIQUE WHERE (admin AND (deleted_at IS NULL))
#  index_roles_on_organization_id        (organization_id)
#
