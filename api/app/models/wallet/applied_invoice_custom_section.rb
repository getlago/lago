# frozen_string_literal: true

class Wallet::AppliedInvoiceCustomSection < ApplicationRecord
  self.table_name = "wallets_invoice_custom_sections"

  belongs_to :organization
  belongs_to :wallet
  belongs_to :invoice_custom_section
end

# == Schema Information
#
# Table name: wallets_invoice_custom_sections
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  invoice_custom_section_id :uuid             not null
#  organization_id           :uuid             not null
#  wallet_id                 :uuid             not null
#
# Indexes
#
#  idx_on_invoice_custom_section_id_aca4661c33               (invoice_custom_section_id)
#  index_wallets_invoice_custom_sections_on_organization_id  (organization_id)
#  index_wallets_invoice_custom_sections_on_wallet_id        (wallet_id)
#  index_wallets_invoice_custom_sections_unique              (wallet_id,invoice_custom_section_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invoice_custom_section_id => invoice_custom_sections.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (wallet_id => wallets.id)
#
