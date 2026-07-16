# frozen_string_literal: true

class WalletTransaction::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "wallet_transactions_invoice_custom_sections"

  belongs_to :organization
  belongs_to :wallet_transaction
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: wallet_transactions_invoice_custom_sections
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  invoice_custom_section_id :uuid             not null
#  organization_id           :uuid             not null
#  wallet_transaction_id     :uuid             not null
#
# Indexes
#
#  idx_on_invoice_custom_section_id_b381df5bb5  (invoice_custom_section_id)
#  idx_on_organization_id_ccdf05cbfe            (organization_id)
#  idx_on_wallet_transaction_id_ac2826109e      (wallet_transaction_id)
#  index_wt_invoice_custom_sections_unique      (wallet_transaction_id,invoice_custom_section_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (wallet_transaction_id => wallet_transactions.id)
#
