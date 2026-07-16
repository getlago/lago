# frozen_string_literal: true

class AddOn
  class AppliedTax < ApplicationRecord
    self.table_name = "add_ons_taxes"

    belongs_to :add_on
    belongs_to :tax
    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: add_ons_taxes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  add_on_id       :uuid             not null
#  organization_id :uuid             not null
#  tax_id          :uuid             not null
#
# Indexes
#
#  index_add_ons_taxes_on_add_on_id             (add_on_id)
#  index_add_ons_taxes_on_add_on_id_and_tax_id  (add_on_id,tax_id) UNIQUE
#  index_add_ons_taxes_on_organization_id       (organization_id)
#  index_add_ons_taxes_on_tax_id                (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (add_on_id => add_ons.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id)
#
