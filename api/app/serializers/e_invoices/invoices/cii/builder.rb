# frozen_string_literal: true

module EInvoices
  module Invoices::Cii
    class Builder < EInvoices::Cii::BaseSerializer
      include Invoices::Common

      def initialize(xml:, invoice:)
        super(xml:, resource: invoice)

        @invoice = invoice
      end

      def serialize
        Cii::CrossIndustryInvoice.serialize(xml:) do
          Cii::Header.serialize(xml:, resource: invoice, type_code: invoice_type_code, notes:)

          xml.comment "Supply Chain Trade Transaction"
          xml["rsm"].SupplyChainTradeTransaction do
            line_items(:fees) do |fee, line_id|
              Cii::LineItem.serialize(xml:, resource:, data: line_item_data(line_id, fee))
            end

            Cii::TradeAgreement.serialize(xml:, resource:, options: trade_aggreement_options)
            Cii::TradeDelivery.serialize(xml:, delivery_date:)
            Cii::TradeSettlement.serialize(xml:, resource:) do
              credits_and_payments do |type, amount|
                Cii::TradeSettlementPayment.serialize(xml:, resource:, type:, amount:)
              end

              taxes do |tax_category, tax_rate, basis_amount, tax_amount|
                Cii::ApplicableTradeTax.serialize(xml:, tax_category:, tax_rate:, basis_amount:, tax_amount:)
              end

              allowance_charges do |tax_rate, amount|
                Cii::TradeAllowanceCharge.serialize(xml:, resource:, indicator: INVOICE_DISCOUNT, tax_rate:, amount:)
              end

              Cii::PaymentTerms.serialize(xml:, due_date: invoice.payment_due_date, description: payment_terms_description)
              Cii::MonetarySummation.serialize(xml:, resource:, amounts: monetary_summation_amounts)
            end
          end
        end
      end

      private

      attr_accessor :xml, :invoice

      def trade_aggreement_options
        Cii::TradeAgreement::Options.new(
          tax_registration: !invoice.credit?
        )
      end

      def monetary_summation_amounts
        Cii::MonetarySummation::Amounts.new(
          line_total_amount: invoice.fees_amount,
          allowances_amount: Money.new(allowances),
          tax_basis_amount: invoice.sub_total_excluding_taxes_amount,
          tax_amount: invoice.taxes_amount,
          grand_total_amount: invoice.sub_total_including_taxes_amount,
          prepaid_amount: invoice.prepaid_credit_amount + invoice.credit_notes_amount,
          due_payable_amount: invoice.total_amount
        )
      end

      def line_item_data(index, fee)
        category = tax_category_code(type: fee.fee_type, tax_rate: fee.taxes_rate)
        Cii::LineItem::Data.new(
          line_id: index,
          name: fee.item_name,
          description: fee_description(fee),
          charge_amount: fee.precise_unit_amount,
          billed_quantity: fee.units,
          category_code: category,
          rate_percent: (category != O_CATEGORY) ? fee.taxes_rate : nil,
          line_total_amount: fee.amount
        )
      end
    end
  end
end
