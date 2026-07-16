# frozen_string_literal: true

module EInvoices
  module Cii
    class LineItem < BaseSerializer
      Data = Data.define(
        :line_id,
        :name,
        :description,
        :charge_amount,
        :billed_quantity,
        :category_code,
        :rate_percent,
        :line_total_amount
      )

      def initialize(xml:, resource:, data:)
        super(xml:, resource:)

        @data = data
      end

      def serialize
        xml.comment "Line Item #{data.line_id}: #{data.description}"
        xml["ram"].IncludedSupplyChainTradeLineItem do
          xml["ram"].AssociatedDocumentLineDocument do
            xml["ram"].LineID data.line_id
          end
          xml["ram"].SpecifiedTradeProduct do
            xml["ram"].Name data.name
            xml["ram"].Description data.description
          end
          xml["ram"].SpecifiedLineTradeAgreement do
            xml["ram"].NetPriceProductTradePrice do
              xml["ram"].ChargeAmount data.charge_amount
            end
          end
          xml["ram"].SpecifiedLineTradeDelivery do
            xml["ram"].BilledQuantity data.billed_quantity, unitCode: UNIT_CODE
          end
          xml["ram"].SpecifiedLineTradeSettlement do
            xml["ram"].ApplicableTradeTax do
              xml["ram"].TypeCode VAT
              xml["ram"].CategoryCode data.category_code
              xml["ram"].RateApplicablePercent data.rate_percent if data.rate_percent.present?
            end
            xml["ram"].SpecifiedTradeSettlementLineMonetarySummation do
              xml["ram"].LineTotalAmount format_number(data.line_total_amount)
            end
          end
        end
      end

      private

      attr_accessor :data
    end
  end
end
