# frozen_string_literal: true

class Commitment
  class AppliedTax < ApplicationRecord
    self.table_name = "commitments_taxes"

    belongs_to :commitment
    belongs_to :tax
    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: commitments_taxes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  commitment_id   :uuid             not null
#  organization_id :uuid             not null
#  tax_id          :uuid             not null
#
# Indexes
#
#  index_commitments_taxes_on_commitment_id             (commitment_id)
#  index_commitments_taxes_on_commitment_id_and_tax_id  (commitment_id,tax_id) UNIQUE
#  index_commitments_taxes_on_organization_id           (organization_id)
#  index_commitments_taxes_on_tax_id                    (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (commitment_id => commitments.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id)
#
