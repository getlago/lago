# frozen_string_literal: true

module EInvoices
  module Ubl
    class MonetaryTotal < BaseSerializer
      Amounts = Data.define(
        :line_extension_amount,
        :tax_exclusive_amount,
        :tax_inclusive_amount,
        :allowance_total_amount,
        :charge_total_amount,
        :prepaid_amount,
        :payable_amount
      ) do
        def initialize(allowance_total_amount: 0, charge_total_amount: 0, **rest)
          super
        end
      end

      def initialize(xml:, resource:, amounts:)
        super(xml:, resource:)

        @amounts = amounts
      end

      def serialize
        xml.comment "Legal Monetary Total"
        xml["cac"].LegalMonetaryTotal do
          xml["cbc"].LineExtensionAmount format_number(amounts.line_extension_amount), currencyID: resource.currency
          xml["cbc"].TaxExclusiveAmount format_number(amounts.tax_exclusive_amount), currencyID: resource.currency
          xml["cbc"].TaxInclusiveAmount format_number(amounts.tax_inclusive_amount), currencyID: resource.currency
          xml["cbc"].AllowanceTotalAmount format_number(amounts.allowance_total_amount), currencyID: resource.currency
          xml["cbc"].ChargeTotalAmount format_number(amounts.charge_total_amount), currencyID: resource.currency
          xml["cbc"].PrepaidAmount format_number(amounts.prepaid_amount), currencyID: resource.currency
          xml["cbc"].PayableAmount format_number(amounts.payable_amount), currencyID: resource.currency
        end
      end

      private

      attr_accessor :amounts
    end
  end
end
