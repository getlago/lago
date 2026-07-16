# frozen_string_literal: true

class BillingEntity::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "billing_entities_invoice_custom_sections"

  belongs_to :organization
  belongs_to :billing_entity
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: billing_entities_invoice_custom_sections
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  billing_entity_id         :uuid             not null
#  invoice_custom_section_id :uuid             not null
#  organization_id           :uuid             not null
#
# Indexes
#
#  idx_on_billing_entity_id_724373e5ae                            (billing_entity_id)
#  idx_on_billing_entity_id_invoice_custom_section_id_bd78c547d3  (billing_entity_id,invoice_custom_section_id) UNIQUE
#  idx_on_invoice_custom_section_id_ccb39e9622                    (invoice_custom_section_id)
#  idx_on_organization_id_83703a45f4                              (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id)
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#
