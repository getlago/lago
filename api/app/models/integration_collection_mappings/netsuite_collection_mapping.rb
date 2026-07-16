# frozen_string_literal: true

module IntegrationCollectionMappings
  class NetsuiteCollectionMapping < BaseCollectionMapping
    settings_accessors :tax_nexus, :tax_type, :tax_code
    settings_accessors :currencies

    validate :currency_mapping_format
    validate :organization_level_only_mapping

    private

    def organization_level_only_mapping
      if currencies? && billing_entity_id.present?
        errors.add(:billing_entity, "value_must_be_blank")
      end
    end

    def currency_mapping_format
      # Other mapping_types shouldn't have currencies, but if they do, we validate the format
      return if !currencies? && currencies.nil?

      if !currencies? && currencies.present?
        errors.add(:currencies, "value_must_be_blank")
        return
      end

      if currencies? && currencies.nil?
        errors.add(:currencies, "value_is_mandatory")
        return
      end

      if !currencies.is_a?(Hash)
        errors.add(:currencies, "invalid_format")
      elsif currencies.empty?
        errors.add(:currencies, "cannot_be_empty")
      elsif !currencies_hash_valid?
        errors.add(:currencies, "invalid_format")
      end
    end

    def currencies_hash_valid?
      valid_currencies = Currencies::ACCEPTED_CURRENCIES.keys
      currencies.keys.all? { it.is_a?(String) && valid_currencies.include?(it.to_sym) } &&
        currencies.values.all? { it.is_a?(String) && it.present? }
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
