# frozen_string_literal: true

module V1
  class CommitmentSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        plan_code: model.plan.code,
        invoice_display_name: model.invoice_display_name,
        commitment_type: model.commitment_type,
        amount_cents: model.amount_cents,
        interval: model.plan.interval,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
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
