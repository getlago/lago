# frozen_string_literal: true

module EInvoices
  module Cii
    class TradeAllowanceCharge < BaseSerializer
      def initialize(xml:, resource:, indicator:, tax_rate:, amount:)
        super(xml:, resource:)

        @indicator = indicator
        @tax_rate = tax_rate
        @amount = amount
      end

      def serialize
        xml.comment "Allowance/Charge - Discount #{percent(tax_rate)} portion"
        xml["ram"].SpecifiedTradeAllowanceCharge do
          xml["ram"].ChargeIndicator do
            xml["udt"].Indicator indicator
          end
          xml["ram"].ActualAmount format_number(amount)
          xml["ram"].Reason discount_reason
          xml["ram"].CategoryTradeTax do
            xml["ram"].TypeCode VAT
            xml["ram"].CategoryCode tax_category_code(tax_rate:)
            xml["ram"].RateApplicablePercent format_number(tax_rate)
          end
        end
      end

      private

      attr_accessor :indicator, :tax_rate, :amount
    end
  end
end
