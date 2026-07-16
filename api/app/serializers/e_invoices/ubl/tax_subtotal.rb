# frozen_string_literal: true

module EInvoices
  module Ubl
    class TaxSubtotal < BaseSerializer
      def initialize(xml:, resource:, tax_category:, tax_rate:, basis_amount:, tax_amount:)
        super(xml:, resource:)

        @tax_category = tax_category
        @tax_rate = tax_rate
        @basis_amount = basis_amount
        @tax_amount = tax_amount
      end

      def serialize
        xml.comment "Tax Information #{percent(tax_rate)} #{VAT}"
        xml["cac"].TaxSubtotal do
          xml["cbc"].TaxableAmount format_number(basis_amount), currencyID: resource.currency
          xml["cbc"].TaxAmount format_number(tax_amount), currencyID: resource.currency
          xml["cac"].TaxCategory do
            xml["cbc"].ID tax_category
            if outside_scope_of_tax?
              xml["cbc"].TaxExemptionReasonCode O_VAT_EXEMPTION
              xml["cbc"].TaxExemptionReason "Not subject to VAT"
            else
              xml["cbc"].Percent format_number(tax_rate)
            end
            xml["cac"].TaxScheme do
              xml["cbc"].ID VAT
            end
          end
        end
      end

      private

      attr_accessor :tax_category, :tax_rate, :basis_amount, :tax_amount

      def outside_scope_of_tax?
        tax_category == O_CATEGORY
      end
    end
  end
end
