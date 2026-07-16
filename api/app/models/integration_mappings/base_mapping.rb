# frozen_string_literal: true

module IntegrationMappings
  class BaseMapping < ApplicationRecord
    include PaperTrailTraceable
    include SettingsStorable

    self.table_name = "integration_mappings"

    belongs_to :integration, class_name: "Integrations::BaseIntegration"
    belongs_to :mappable, polymorphic: true
    belongs_to :organization
    belongs_to :billing_entity, optional: true

    MAPPABLE_TYPES = %i[AddOn BillableMetric].freeze

    validates :mappable_type, inclusion: {in: MAPPABLE_TYPES.map(&:to_s)}
    validates :mappable_type,
      uniqueness: {scope: [:mappable_id, :integration_id, :organization_id, :billing_entity_id]}
    validate :validate_billing_entity_organization

    settings_accessors :external_id, :external_account_code, :external_name

    private

    def validate_billing_entity_organization
      return unless billing_entity

      errors.add(:billing_entity, "must belong to the same organization") if billing_entity.organization_id != organization_id
    end
  end
end

# == Schema Information
#
# Table name: integration_mappings
# Database name: primary
#
#  id                :uuid             not null, primary key
#  mappable_type     :string           not null
#  settings          :jsonb            not null
#  type              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  billing_entity_id :uuid
#  integration_id    :uuid             not null
#  mappable_id       :uuid             not null
#  organization_id   :uuid             not null
#
# Indexes
#
#  index_integration_mappings_on_integration_id                     (integration_id)
#  index_integration_mappings_on_mappable                           (mappable_type,mappable_id)
#  index_integration_mappings_on_organization_id                    (organization_id)
#  index_integration_mappings_unique_billing_entity_id_is_not_null  (mappable_type,mappable_id,integration_id,billing_entity_id) UNIQUE WHERE (billing_entity_id IS NOT NULL)
#  index_integration_mappings_unique_billing_entity_id_is_null      (mappable_type,mappable_id,integration_id,organization_id) UNIQUE WHERE (billing_entity_id IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id) ON DELETE => cascade
#  fk_rails_...  (integration_id => integrations.id)
#  fk_rails_...  (organization_id => organizations.id)
#
