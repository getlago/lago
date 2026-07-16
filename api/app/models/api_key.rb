# frozen_string_literal: true

class ApiKey < ApplicationRecord
  include PaperTrailTraceable

  RESOURCES = %w[
    activity_log add_on analytic api_log billable_metric coupon applied_coupon credit_note customer_usage
    customer event fee invoice organization order order_form payment payment_receipt payment_request payment_method plan subscription lifetime_usage
    tax wallet wallet_transaction webhook_endpoint webhook_jwt_public_key invoice_custom_section
    billing_entity alert feature security_log quote
  ].freeze

  MODES = %w[read write].freeze

  attribute :permissions, default: -> { default_permissions }

  belongs_to :organization

  before_create :set_value

  validates :value, uniqueness: true
  validates :value, presence: true, on: :update
  validates :permissions, presence: true
  validate :permissions_keys_compliance
  validate :permissions_values_allowed

  default_scope { active }

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :non_expiring, -> { where(expires_at: nil) }
  scope :with_most_permissions, -> { order(Arel.sql("(SELECT SUM(jsonb_array_length(value)) FROM jsonb_each(permissions))")).last }

  def flat_permissions
    permissions.flat_map { |resource, modes| Array(modes).map { |mode| "#{resource}:#{mode}" } }.sort
  end

  def permit?(resource, mode)
    return true unless organization.api_permissions_enabled?

    Array(permissions[resource]).include?(mode)
  end

  def self.default_permissions
    RESOURCES.index_with { MODES.dup }
  end

  def expired?(time = Time.current)
    expires_at.present? && expires_at < time
  end

  private

  def permissions_keys_compliance
    return unless permissions

    forbidden_permissions = permissions.keys - RESOURCES

    if forbidden_permissions.any?
      errors.add(:permissions, :forbidden_keys, keys: forbidden_permissions)
    end
  end

  def permissions_values_allowed
    return unless permissions

    forbidden_values = permissions.values.flatten - MODES

    if forbidden_values.any?
      errors.add(:permissions, :forbidden_values, values: forbidden_values)
    end
  end

  def set_value
    loop do
      self.value = SecureRandom.uuid
      break unless self.class.exists?(value:)
    end
  end
end

# == Schema Information
#
# Table name: api_keys
# Database name: primary
#
#  id              :uuid             not null, primary key
#  expires_at      :datetime
#  last_used_at    :datetime
#  name            :string
#  permissions     :jsonb            not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_api_keys_on_organization_id  (organization_id)
#  index_api_keys_on_value            (value) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
