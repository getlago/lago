# frozen_string_literal: true

class Customer::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "customers_invoice_custom_sections"

  belongs_to :organization
  belongs_to :billing_entity
  belongs_to :customer
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: customers_invoice_custom_sections
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  billing_entity_id         :uuid             not null
#  customer_id               :uuid             not null
#  invoice_custom_section_id :uuid             not null
#  organization_id           :uuid             not null
#
# Indexes
#
#  idx_on_billing_entity_id_customer_id_invoice_custom_e7aada65cb  (billing_entity_id,customer_id,invoice_custom_section_id) UNIQUE
#  idx_on_invoice_custom_section_id_5f37496c8c                     (invoice_custom_section_id)
#  index_customers_invoice_custom_sections_on_billing_entity_id    (billing_entity_id)
#  index_customers_invoice_custom_sections_on_customer_id          (customer_id)
#  index_customers_invoice_custom_sections_on_organization_id      (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id)
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#
