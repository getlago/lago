# frozen_string_literal: true

module V1
  class CreditNoteSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        billing_entity_code: model.invoice.billing_entity.code,
        sequential_id: model.sequential_id,
        number: model.number,
        lago_invoice_id: model.invoice_id,
        invoice_number: model.invoice.number,
        purchase_order_number: model.purchase_order_number,
        issuing_date: model.issuing_date.iso8601,
        credit_status: model.credit_status,
        refund_status: model.refund_status,
        reason: model.reason,
        description: model.description,
        currency: model.currency,
        total_amount_cents: model.total_amount_cents,
        precise_total_amount_cents: model.precise_total&.to_s,
        taxes_amount_cents: model.taxes_amount_cents,
        precise_taxes_amount_cents: model.precise_taxes_amount_cents&.to_s,
        sub_total_excluding_taxes_amount_cents: model.sub_total_excluding_taxes_amount_cents,
        balance_amount_cents: model.balance_amount_cents,
        credit_amount_cents: model.credit_amount_cents,
        refund_amount_cents: model.refund_amount_cents,
        offset_amount_cents: model.offset_amount_cents,
        coupons_adjustment_amount_cents: model.coupons_adjustment_amount_cents,
        taxes_rate: model.taxes_rate,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601,
        file_url: model.file_url,
        xml_url: model.xml_url,
        self_billed: model.invoice.self_billed
      }

      payload.merge!(customer) if include?(:customer)
      payload.merge!(items) if include?(:items)
      payload.merge!(applied_taxes) if include?(:applied_taxes)
      payload.merge!(error_details) if include?(:error_details)
      payload.merge!(metadata) if model.metadata.present?

      payload
    end

    private

    def customer
      {
        customer: ::V1::CustomerSerializer.new(
          model.customer,
          includes: included_relations(:customer, default: [])
        ).serialize
      }
    end

    def items
      ::CollectionSerializer.new(
        model.items.sort_by(&:created_at),
        ::V1::CreditNoteItemSerializer,
        collection_name: "items"
      ).serialize
    end

    def applied_taxes
      ::CollectionSerializer.new(
        model.applied_taxes,
        ::V1::CreditNotes::AppliedTaxSerializer,
        collection_name: "applied_taxes"
      ).serialize
    end

    def error_details
      ::CollectionSerializer.new(
        model.error_details,
        ::V1::ErrorDetailSerializer,
        collection_name: "error_details"
      ).serialize
    end

    def metadata
      {
        metadata: ::V1::MetadataSerializer.new(model.metadata).serialize
      }
    end
  end
end
