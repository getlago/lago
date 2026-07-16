# frozen_string_literal: true

class Invoice
  class AppliedTax < ApplicationRecord
    self.table_name = "invoices_taxes"

    include PaperTrailTraceable

    belongs_to :organization
    belongs_to :invoice
    # NOTE: Tax isn't really optional, but we used to hard deleted taxes,
    #       so some AppliedTax had no tax relation
    belongs_to :tax, -> { with_discarded }, optional: true

    monetize :amount_cents,
      :fees_amount_cents,
      :taxable_amount_cents,
      with_model_currency: :amount_currency

    validates :amount_cents, numericality: {greater_than_or_equal_to: 0}

    TAX_CODES_APPLICABLE_ON_WHOLE_INVOICE = %w[not_collecting juris_not_taxed reverse_charge customer_exempt
      transaction_exempt juris_has_no_tax unknown_taxation].freeze

    def applied_on_whole_invoice?
      TAX_CODES_APPLICABLE_ON_WHOLE_INVOICE.include?(tax_code)
    end

    def taxable_amount_cents
      base_amount = taxable_base_amount_cents

      return fees_amount_cents if base_amount.blank? || base_amount.zero?

      base_amount
    end
  end
end

# == Schema Information
#
# Table name: invoices_taxes
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  amount_cents              :bigint           default(0), not null
#  amount_currency           :string           not null
#  fees_amount_cents         :bigint           default(0), not null
#  tax_code                  :string           not null
#  tax_description           :string
#  tax_name                  :string           not null
#  tax_rate                  :float            default(0.0), not null
#  taxable_base_amount_cents :bigint           default(0), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  invoice_id                :uuid             not null
#  organization_id           :uuid             not null
#  tax_id                    :uuid
#
# Indexes
#
#  index_invoices_taxes_on_invoice_id             (invoice_id)
#  index_invoices_taxes_on_invoice_id_and_tax_id  (invoice_id,tax_id) UNIQUE WHERE ((tax_id IS NOT NULL) AND (created_at >= '2023-09-12 00:00:00'::timestamp without time zone))
#  index_invoices_taxes_on_organization_id        (organization_id)
#  index_invoices_taxes_on_tax_id                 (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (tax_id => taxes.id) ON DELETE => nullify
#
