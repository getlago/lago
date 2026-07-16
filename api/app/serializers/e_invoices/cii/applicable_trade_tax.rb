# frozen_string_literal: true

module EInvoices
  module Cii
    class ApplicableTradeTax < BaseSerializer
      def initialize(xml:, tax_category:, tax_rate:, basis_amount:, tax_amount:)
        super(xml:)

        @tax_category = tax_category
        @tax_rate = tax_rate
        @basis_amount = basis_amount
        @tax_amount = tax_amount
      end

      def serialize
        xml.comment "Tax Information #{percent(tax_rate)} #{VAT}"
        xml["ram"].ApplicableTradeTax do
          xml["ram"].CalculatedAmount format_number(tax_amount)
          xml["ram"].TypeCode VAT
          xml["ram"].BasisAmount format_number(basis_amount)
          xml["ram"].CategoryCode tax_category
          if outside_scope_of_tax?
            xml["ram"].ExemptionReasonCode O_VAT_EXEMPTION
          else
            xml["ram"].RateApplicablePercent format_number(tax_rate)
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
