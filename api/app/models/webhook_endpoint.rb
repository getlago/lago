# frozen_string_literal: true

class WebhookEndpoint < ApplicationRecord
  LIMIT = 10

  SIGNATURE_ALGOS = [
    :jwt,
    :hmac
  ].freeze

  WEBHOOK_EVENT_TYPE_CONFIG = YAML.safe_load_file(
    Rails.root.join("config/webhook_event_types.yml"),
    symbolize_names: true
  ).freeze

  WEBHOOK_EVENT_TYPES = WEBHOOK_EVENT_TYPE_CONFIG.map do |_, config|
    config[:name].to_s
  end.freeze

  belongs_to :organization
  has_many :webhooks, dependent: :delete_all

  validates :webhook_url, presence: true, url: true
  validates :webhook_url, uniqueness: {scope: :organization_id}
  validate :max_webhook_endpoints, on: :create
  validate :validate_event_types, if: :event_types_changed?

  before_validation :normalize_event_types, if: :event_types_changed?

  enum :signature_algo, SIGNATURE_ALGOS

  def self.ransackable_attributes(_auth_object = nil)
    %w[webhook_url]
  end

  private

  def max_webhook_endpoints
    errors.add(:base, :exceeded_limit) if organization &&
      organization.webhook_endpoints.reload.count >= LIMIT
  end

  def validate_event_types
    return if event_types.nil?

    # since AR casts non-array values to [] we need to check the raw value
    if event_types.is_a?(Array) && event_types.blank? && !event_types_before_type_cast.is_a?(Array)
      errors.add(:event_types, :must_be_array)
    end

    invalid_types = event_types - WEBHOOK_EVENT_TYPES
    if invalid_types.present?
      errors.add(:event_types, :invalid_types, invalid_types:)
    end
  end

  def normalize_event_types
    return if event_types.blank?

    normalized = event_types
      .map { |event_type| event_type&.to_s&.strip&.downcase }
      .reject(&:blank?)
      .uniq

    # special case: convert ["*"] to nil to disable filtering
    if normalized.length == 1 && normalized.first == "*"
      normalized = nil
    end

    self.event_types = normalized
  end
end

# == Schema Information
#
# Table name: webhook_endpoints
# Database name: primary
#
#  id              :uuid             not null, primary key
#  event_types     :string           is an Array
#  name            :string
#  signature_algo  :integer          default("jwt"), not null
#  webhook_url     :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_webhook_endpoints_on_organization_id                  (organization_id)
#  index_webhook_endpoints_on_webhook_url_and_organization_id  (webhook_url,organization_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
