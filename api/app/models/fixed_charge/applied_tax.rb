# frozen_string_literal: true

class FixedCharge::AppliedTax < ApplicationRecord
  self.table_name = "fixed_charges_taxes"

  belongs_to :fixed_charge
  belongs_to :tax
  belongs_to :organization
end

# == Schema Information
#
# Table name: fixed_charges_taxes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  fixed_charge_id :uuid             not null
#  organization_id :uuid             not null
#  tax_id          :uuid             not null
#
# Indexes
#
#  index_fixed_charges_taxes_on_fixed_charge_id             (fixed_charge_id)
#  index_fixed_charges_taxes_on_fixed_charge_id_and_tax_id  (fixed_charge_id,tax_id) UNIQUE
#  index_fixed_charges_taxes_on_organization_id             (organization_id)
#  index_fixed_charges_taxes_on_tax_id                      (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (fixed_charge_id => fixed_charges.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id)
#
