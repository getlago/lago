# frozen_string_literal: true

class Customer
  class AppliedTax < ApplicationRecord
    self.table_name = "customers_taxes"

    include PaperTrailTraceable

    belongs_to :customer
    belongs_to :tax
    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: customers_taxes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  customer_id     :uuid             not null
#  organization_id :uuid             not null
#  tax_id          :uuid             not null
#
# Indexes
#
#  index_customers_taxes_on_customer_id             (customer_id)
#  index_customers_taxes_on_customer_id_and_tax_id  (customer_id,tax_id) UNIQUE
#  index_customers_taxes_on_organization_id         (organization_id)
#  index_customers_taxes_on_tax_id                  (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id)
#
