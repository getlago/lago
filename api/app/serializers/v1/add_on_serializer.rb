# frozen_string_literal: true

module V1
  class AddOnSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        name: model.name,
        invoice_display_name: model.invoice_display_name,
        code: model.code,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        created_at: model.created_at.iso8601,
        description: model.description
      }

      payload.merge!(taxes) if include?(:taxes)
      payload
    end

    private

    def taxes
      ::CollectionSerializer.new(
        model.taxes,
        ::V1::TaxSerializer,
        collection_name: "taxes"
      ).serialize
    end
  end
end
