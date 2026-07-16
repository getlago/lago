# frozen_string_literal: true

module Clickhouse
  class SecurityLog < BaseRecord
    self.table_name = "security_logs"
    self.primary_key = nil

    belongs_to :organization
    belongs_to :user, optional: true
    belongs_to :api_key, optional: true

    default_scope -> { where(logged_at: Organization::SECURITY_LOGS_RETENTION_DAYS.days.ago..) }

    LOG_TYPES = %w[
      api_key
      billing_entity
      export
      integration
      role
      user
      webhook_endpoint
    ].freeze

    LOG_EVENTS = %w[
      api_key.created
      api_key.deleted
      api_key.rotated
      api_key.updated
      billing_entity.created
      billing_entity.updated
      export.created
      integration.created
      integration.deleted
      integration.updated
      role.created
      role.deleted
      role.updated
      user.deleted
      user.new_device_logged_in
      user.invited
      user.password_edited
      user.password_reset_requested
      user.role_edited
      user.signed_up
      webhook_endpoint.created
      webhook_endpoint.deleted
      webhook_endpoint.updated
    ].freeze

    before_save :ensure_log_id

    def resources
      deep_parse_map_values(super)
    end

    def device_info
      deep_parse_map_values(super)
    end

    private

    def ensure_log_id
      self.log_id = SecureRandom.uuid if log_id.blank?
    end

    def deep_parse_map_values(hash)
      return hash unless hash.is_a?(Hash)

      hash.transform_values do |v|
        JSON.parse(v)
      rescue JSON::ParserError
        v
      end
    end
  end
end

# == Schema Information
#
# Table name: security_logs
# Database name: clickhouse
#
#  device_info     :string
#  log_event       :string           not null
#  log_type        :string           not null
#  logged_at       :datetime         not null
#  resources       :string
#  created_at      :datetime         not null
#  api_key_id      :string
#  log_id          :string           not null
#  organization_id :string           not null
#  user_id         :string
#
