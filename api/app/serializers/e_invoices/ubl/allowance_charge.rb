# frozen_string_literal: true

module EInvoices
  module Ubl
    class AllowanceCharge < BaseSerializer
      def initialize(xml:, resource:, indicator:, tax_rate:, amount:)
        super(xml:, resource:)

        @indicator = indicator
        @tax_rate = tax_rate
        @amount = amount
      end

      def serialize
        xml.comment "Allowances and Charges - Discount #{percent(tax_rate)} portion"
        xml["cac"].AllowanceCharge do
          xml["cbc"].ChargeIndicator indicator
          xml["cbc"].AllowanceChargeReason discount_reason
          xml["cbc"].Amount amount, currencyID: resource.currency
          xml["cac"].TaxCategory do
            xml["cbc"].ID tax_category_code(tax_rate:)
            xml["cbc"].Percent format_number(tax_rate)
            xml["cac"].TaxScheme do
              xml["cbc"].ID VAT
            end
          end
        end
      end

      private

      attr_accessor :indicator, :tax_rate, :amount
    end
  end
end
