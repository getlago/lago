# frozen_string_literal: true

module IntegrationCollectionMappings
  class XeroCollectionMapping < BaseCollectionMapping
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
