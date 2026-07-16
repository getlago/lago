# frozen_string_literal: true

class Charge
  class AppliedTax < ApplicationRecord
    self.table_name = "charges_taxes"

    belongs_to :charge
    belongs_to :tax
    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: charges_taxes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  charge_id       :uuid             not null
#  organization_id :uuid             not null
#  tax_id          :uuid             not null
#
# Indexes
#
#  index_charges_taxes_on_charge_id             (charge_id)
#  index_charges_taxes_on_charge_id_and_tax_id  (charge_id,tax_id) UNIQUE
#  index_charges_taxes_on_organization_id       (organization_id)
#  index_charges_taxes_on_tax_id                (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id)
#
