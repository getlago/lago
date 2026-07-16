# frozen_string_literal: true

module EInvoices
  module Ubl
    class LineItem < BaseSerializer
      Data = Data.define(
        :type,
        :line_id,
        :quantity,
        :line_extension_amount,
        :currency,
        :item_name,
        :item_category,
        :item_rate_percent,
        :item_description,
        :price_amount
      )

      def initialize(xml:, resource:, data:)
        super(xml:, resource:)

        @data = data
      end

      def serialize
        xml.comment "Line Item #{data.line_id}: #{data.item_description}"
        xml["cac"].send(line_tag) do
          xml["cbc"].ID data.line_id
          xml["cbc"].send(quantity_tag, format_number(data.quantity), unitCode: UNIT_CODE)
          xml["cbc"].LineExtensionAmount format_number(data.line_extension_amount), currencyID: data.currency
          xml["cac"].Item do
            xml["cbc"].Name data.item_name
            xml["cac"].ClassifiedTaxCategory do
              xml["cbc"].ID data.item_category
              xml["cbc"].Percent data.item_rate_percent if data.item_rate_percent.present?
              xml["cac"].TaxScheme do
                xml["cbc"].ID VAT
              end
            end
            xml["cac"].AdditionalItemProperty do
              xml["cbc"].Name "Description"
              xml["cbc"].Value data.item_description
            end
          end
          xml["cac"].Price do
            xml["cbc"].PriceAmount data.price_amount, currencyID: data.currency
          end
        end
      end

      private

      attr_accessor :data

      def line_tag
        case data.type
        when :invoice
          :InvoiceLine
        when :credit_note
          :CreditNoteLine
        end
      end

      def quantity_tag
        case data.type
        when :invoice
          :InvoicedQuantity
        when :credit_note
          :CreditedQuantity
        end
      end
    end
  end
end
