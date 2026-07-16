# frozen_string_literal: true

class RecurringTransactionRule::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "recurring_transaction_rules_invoice_custom_sections"

  belongs_to :organization
  belongs_to :recurring_transaction_rule
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: recurring_transaction_rules_invoice_custom_sections
# Database name: primary
#
#  id                            :uuid             not null, primary key
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  invoice_custom_section_id     :uuid             not null
#  organization_id               :uuid             not null
#  recurring_transaction_rule_id :uuid             not null
#
# Indexes
#
#  idx_on_invoice_custom_section_id_50c2a2e7c0      (invoice_custom_section_id)
#  idx_on_organization_id_e73219f079                (organization_id)
#  idx_on_recurring_transaction_rule_id_fba3d39cca  (recurring_transaction_rule_id)
#  index_rtr_invoice_custom_sections_unique         (recurring_transaction_rule_id,invoice_custom_section_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (recurring_transaction_rule_id => recurring_transaction_rules.id)
#
