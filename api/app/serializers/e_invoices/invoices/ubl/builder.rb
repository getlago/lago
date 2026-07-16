# frozen_string_literal: true

module EInvoices
  module Invoices::Ubl
    class Builder < EInvoices::Ubl::BaseSerializer
      include Invoices::Common

      def initialize(xml:, invoice: nil)
        super(xml:, resource: invoice)

        @invoice = invoice
      end

      def serialize
        xml.Invoice(INVOICE_NAMESPACES) do
          xml.comment "UBL Version and Customization"
          xml["cbc"].UBLVersionID "2.1"
          xml["cbc"].CustomizationID customization_id
          xml["cbc"].ProfileID PEPPOL_BIS_BILLING_PROFILE if de_billing_entity?

          Ubl::Header.serialize(xml:, resource:, type_code: invoice_type_code)
          Ubl::OrderReference.serialize(xml:, id: resource.purchase_order_number) if resource.purchase_order_number.present?
          Ubl::SupplierParty.serialize(xml:, resource:, options: supplier_party_options)
          Ubl::CustomerParty.serialize(xml:, resource:)
          Ubl::Delivery.serialize(xml:, delivery_date:)
          Ubl::PaymentMeans.serialize(xml:, type: STANDARD_PAYMENT, amount: invoice.total_due_amount)
          Ubl::PaymentTerms.serialize(xml:, note: payment_terms_note)

          allowance_charges do |tax_rate, amount|
            Ubl::AllowanceCharge.serialize(xml:, resource:, indicator: INVOICE_DISCOUNT, tax_rate:, amount:)
          end

          xml.comment "Tax Total Information"
          xml["cac"].TaxTotal do
            xml["cbc"].TaxAmount format_number(Money.new(invoice.taxes_amount_cents)), currencyID: invoice.currency

            taxes do |tax_category, tax_rate, basis_amount, tax_amount|
              Ubl::TaxSubtotal.serialize(xml:, resource:, tax_category:, tax_rate:, basis_amount:, tax_amount:)
            end
          end

          Ubl::MonetaryTotal.serialize(xml:, resource:, amounts: monetary_summation_amounts)

          line_items(:fees) do |fee, line_id|
            Ubl::LineItem.serialize(xml:, resource:, data: line_item_data(line_id, fee))
          end
        end
      end

      protected

      attr_accessor :invoice

      def supplier_party_options
        Ubl::SupplierParty::Options.new(
          tax_registration: !invoice.credit?
        )
      end

      def payment_terms_note
        [payment_terms_description, payment_notes].flatten.to_sentence
      end

      def payment_notes
        {
          PREPAID_PAYMENT => invoice.prepaid_credit_amount,
          CREDIT_NOTE_PAYMENT => invoice.credit_notes_amount
        }.map do |type, amount|
          next unless amount.positive?

          payment_information(type, amount)
        end.compact
      end

      def monetary_summation_amounts
        Ubl::MonetaryTotal::Amounts.new(
          line_extension_amount: invoice.fees_amount,
          tax_exclusive_amount: invoice.sub_total_excluding_taxes_amount,
          tax_inclusive_amount: invoice.sub_total_including_taxes_amount,
          allowance_total_amount: Money.new(allowances),
          prepaid_amount: invoice.prepaid_credit_amount + invoice.credit_notes_amount,
          payable_amount: invoice.total_amount
        )
      end

      def line_item_data(index, fee)
        category = tax_category_code(type: fee.fee_type, tax_rate: fee.taxes_rate)
        Ubl::LineItem::Data.new(
          type: :invoice,
          line_id: index,
          quantity: fee.units,
          line_extension_amount: fee.amount,
          currency: fee.currency,
          item_name: fee.item_name,
          item_category: category,
          item_rate_percent: (category != O_CATEGORY) ? fee.taxes_rate : nil,
          item_description: fee_description(fee),
          price_amount: fee.precise_unit_amount
        )
      end
    end
  end
end
