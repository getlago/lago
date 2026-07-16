# frozen_string_literal: true

module Entitlement
  class Privilege < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at

    default_scope -> { kept }

    VALUE_TYPES = %w[integer string boolean select].freeze

    belongs_to :organization
    belongs_to :feature, class_name: "Entitlement::Feature", foreign_key: :entitlement_feature_id
    has_many :values, class_name: "Entitlement::EntitlementValue", foreign_key: :entitlement_privilege_id, dependent: :destroy
    has_many :entitlements, through: :values, class_name: "Entitlement::Entitlement"

    validates :code, presence: true, length: {maximum: 255}
    validates :name, length: {maximum: 255}
    validates :value_type, presence: true, inclusion: {in: VALUE_TYPES}

    validate :validate_config

    private

    def validate_config
      errors.add(:config, :invalid_format) unless config_valid?
    end

    # Config is only used for `select` value_type, and it should contain a list of select_options
    # All other value_types should have an empty config
    def config_valid?
      if value_type == "select"
        config&.keys == ["select_options"] &&
          config["select_options"].is_a?(Array) &&
          !config["select_options"].empty? &&
          config["select_options"].all? { it.is_a?(String) }
      else
        config.blank?
      end
    end
  end
end

# == Schema Information
#
# Table name: entitlement_privileges
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  code                   :string           not null
#  config                 :jsonb            not null
#  deleted_at             :datetime
#  name                   :string
#  value_type             :enum             default("string"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  entitlement_feature_id :uuid             not null
#  organization_id        :uuid             not null
#
# Indexes
#
#  idx_privileges_code_unique_per_feature                  (code,entitlement_feature_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_entitlement_privileges_on_entitlement_feature_id  (entitlement_feature_id)
#  index_entitlement_privileges_on_organization_id         (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (entitlement_feature_id => entitlement_features.id)
#  fk_rails_...  (organization_id => organizations.id)
#
