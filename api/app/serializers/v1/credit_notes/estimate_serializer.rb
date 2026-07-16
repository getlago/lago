# frozen_string_literal: true

module V1
  module CreditNotes
    class EstimateSerializer < ModelSerializer
      def serialize
        payload = {
          lago_invoice_id: model.invoice_id,
          invoice_number: model.invoice.number,
          currency: model.currency,
          taxes_amount_cents: model.taxes_amount_cents,
          precise_taxes_amount_cents: model.precise_taxes_amount_cents,
          sub_total_excluding_taxes_amount_cents: model.sub_total_excluding_taxes_amount_cents,
          max_creditable_amount_cents: model.credit_amount_cents,
          max_refundable_amount_cents: model.refund_amount_cents,
          coupons_adjustment_amount_cents: model.coupons_adjustment_amount_cents,
          precise_coupons_adjustment_amount_cents: model.precise_coupons_adjustment_amount_cents,
          taxes_rate: model.taxes_rate
        }

        payload.merge!(items)
        payload.merge!(applied_taxes)

        payload
      end

      def items
        {
          "items" => model.items.map { |i| {lago_fee_id: i.fee_id, amount_cents: i.amount_cents} }
        }
      end

      def applied_taxes
        collection = ::CollectionSerializer.new(
          model.applied_taxes,
          ::V1::CreditNotes::AppliedTaxSerializer
        ).serialize[:data]

        {
          "applied_taxes" => collection.map { |t| t.except(%i[lago_id lago_credit_note_id created_at]) }
        }
      end
    end
  end
end
