# frozen_string_literal: true

module EInvoices
  module Cii
    class MonetarySummation < BaseSerializer
      Amounts = Data.define(
        :line_total_amount,
        :charges_amount,
        :allowances_amount,
        :tax_basis_amount,
        :tax_amount,
        :grand_total_amount,
        :prepaid_amount,
        :due_payable_amount
      ) do
        def initialize(charges_amount: 0, allowances_amount: 0, prepaid_amount: nil, **rest)
          super
        end
      end

      def initialize(xml:, resource:, amounts:)
        super(xml:, resource:)

        @amounts = amounts
      end

      def serialize
        xml.comment "Monetary Summation"
        xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
          xml["ram"].LineTotalAmount format_number(amounts.line_total_amount)
          xml["ram"].ChargeTotalAmount format_number(amounts.charges_amount)
          xml["ram"].AllowanceTotalAmount format_number(amounts.allowances_amount)
          xml["ram"].TaxBasisTotalAmount format_number(amounts.tax_basis_amount)
          xml["ram"].TaxTotalAmount format_number(amounts.tax_amount), currencyID: resource.currency
          xml["ram"].GrandTotalAmount format_number(amounts.grand_total_amount)
          xml["ram"].TotalPrepaidAmount format_number(amounts.prepaid_amount) if amounts.prepaid_amount.present?
          xml["ram"].DuePayableAmount format_number(amounts.due_payable_amount)
        end
      end

      private

      attr_accessor :amounts
    end
  end
end
