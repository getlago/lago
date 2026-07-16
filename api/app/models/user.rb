# frozen_string_literal: true

class User < ApplicationRecord
  include PaperTrailTraceable

  has_secure_password

  has_many :password_resets
  has_many :user_devices

  has_many :memberships
  has_many :organizations, through: :memberships, class_name: "Organization"

  has_many :active_memberships, -> { where(status: "active") }, class_name: "Membership"
  has_many :active_organizations, through: :active_memberships, source: :organization

  has_many :quote_owners, dependent: :destroy
  has_many :quotes, through: :quote_owners

  validates :email, presence: true
  validates :password, presence: true

  normalizes :email, with: ->(email) { EmailSanitizer.call(email) }

  def can?(permission, organization:)
    memberships.find { |m| m.organization_id == organization.id }&.can?(permission)
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id              :uuid             not null, primary key
#  email           :string
#  password_digest :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
