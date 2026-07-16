# frozen_string_literal: true

module EInvoices
  module CreditNotes::Cii
    class Builder < EInvoices::Cii::BaseSerializer
      include CreditNotes::Common

      def initialize(xml:, credit_note:)
        super(xml:, resource: credit_note)

        @credit_note = credit_note
      end

      def serialize
        Cii::CrossIndustryInvoice.serialize(xml:) do
          Cii::Header.serialize(xml:, resource:, type_code: CREDIT_NOTE, notes:)

          xml.comment "Supply Chain Trade Transaction"
          xml["rsm"].SupplyChainTradeTransaction do
            line_items(:items) do |fee, line_id|
              Cii::LineItem.serialize(xml:, resource:, data: line_item_data(line_id, fee))
            end

            Cii::TradeAgreement.serialize(xml:, resource:)
            Cii::TradeDelivery.serialize(xml:, delivery_date: credit_note.created_at)
            Cii::TradeSettlement.serialize(xml:, resource:) do
              credits_and_payments do |type, amount|
                Cii::TradeSettlementPayment.serialize(xml:, resource:, type:, amount:)
              end

              taxes do |tax_category, tax_rate, basis_amount, tax_amount|
                Cii::ApplicableTradeTax.serialize(xml:, tax_category:, tax_rate:, basis_amount: -basis_amount, tax_amount: -tax_amount)
              end

              allowance_charges do |tax_rate, amount|
                Cii::TradeAllowanceCharge.serialize(xml:, resource:, indicator: INVOICE_CHARGE, tax_rate:, amount: amount)
              end

              Cii::PaymentTerms.serialize(xml:, due_date: credit_note.created_at, description: "Credit note - immediate settlement")
              Cii::MonetarySummation.serialize(xml:, resource:, amounts: monetary_summation_amounts)
            end
          end
        end
      end

      private

      attr_accessor :credit_note

      def monetary_summation_amounts
        Cii::MonetarySummation::Amounts.new(
          line_total_amount: -Money.new(credit_note.items.sum(:precise_amount_cents)),
          charges_amount: Money.new(allowances),
          tax_basis_amount: -Money.new(credit_note.sub_total_excluding_taxes_amount),
          tax_amount: -Money.new(credit_note.taxes_amount),
          grand_total_amount: -Money.new(credit_note.total_amount),
          due_payable_amount: -Money.new(credit_note.credit_amount)
        )
      end

      def line_item_data(index, item)
        category = tax_category_code(type: item.fee.fee_type, tax_rate: item.fee.taxes_rate)
        Cii::LineItem::Data.new(
          line_id: index,
          name: item.fee.item_name,
          description: fee_description(item.fee),
          charge_amount: item.fee.precise_unit_amount,
          billed_quantity: -item.fee.units,
          category_code: category,
          rate_percent: (category != O_CATEGORY) ? item.fee.taxes_rate : nil,
          line_total_amount: Money.new(-item.precise_amount_cents)
        )
      end
    end
  end
end
