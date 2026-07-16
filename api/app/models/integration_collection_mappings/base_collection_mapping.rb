# frozen_string_literal: true

module IntegrationCollectionMappings
  class BaseCollectionMapping < ApplicationRecord
    include PaperTrailTraceable
    include SettingsStorable

    self.table_name = "integration_collection_mappings"

    belongs_to :integration, class_name: "Integrations::BaseIntegration"
    belongs_to :organization
    belongs_to :billing_entity, optional: true

    MAPPING_TYPES = %i[
      fallback_item
      coupon
      subscription_fee
      minimum_commitment
      tax
      prepaid_credit
      credit_note
      account
      currencies
    ].freeze

    enum :mapping_type, MAPPING_TYPES, validate: true

    validates :mapping_type, presence: true
    validates :mapping_type,
      uniqueness: {scope: [:integration_id, :organization_id, :billing_entity_id]}

    validate :validate_billing_entity_organization

    settings_accessors :external_id, :external_account_code, :external_name

    private

    def validate_billing_entity_organization
      return unless billing_entity

      if billing_entity.organization_id != organization_id
        errors.add(:billing_entity, :invalid)
      end
    end
  end
end

# == Schema Information
#
# Table name: integration_collection_mappings
# Database name: primary
#
#  id                :uuid             not null, primary key
#  mapping_type      :integer          not null
#  settings          :jsonb            not null
#  type              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  billing_entity_id :uuid
#  integration_id    :uuid             not null
#  organization_id   :uuid             not null
#
# Indexes
#
#  index_int_collection_mappings_unique_billing_entity_is_not_null  (mapping_type,integration_id,billing_entity_id) UNIQUE WHERE (billing_entity_id IS NOT NULL)
#  index_int_collection_mappings_unique_billing_entity_is_null      (mapping_type,integration_id,organization_id) UNIQUE WHERE (billing_entity_id IS NULL)
#  index_integration_collection_mappings_on_billing_entity_id       (billing_entity_id)
#  index_integration_collection_mappings_on_integration_id          (integration_id)
#  index_integration_collection_mappings_on_organization_id         (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id) ON DELETE => cascade
#  fk_rails_...  (integration_id => integrations.id)
#  fk_rails_...  (organization_id => organizations.id)
#
