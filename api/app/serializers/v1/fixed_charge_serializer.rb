# frozen_string_literal: true

module V1
  class FixedChargeSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_add_on_id: model.add_on_id,
        code: model.code,
        invoice_display_name: model.invoice_display_name,
        add_on_code: model.add_on.code,
        created_at: model.created_at.iso8601,
        charge_model: model.charge_model,
        pay_in_advance: model.pay_in_advance,
        prorated: model.prorated,
        properties: model.properties,
        units: effective_units,
        lago_parent_id: model.parent_id
      }

      payload.merge!(taxes) if include?(:taxes)

      payload
    end

    private

    # Subscription-scoped callers pre-resolve override units into the
    # `effective_units_by_id` option (one query per request, regardless of
    # collection size). Plan-scoped callers (plan endpoints, plan webhooks)
    # don't pass the option and naturally fall back to the plan-level units
    # on the FixedCharge record.
    def effective_units
      options.fetch(:effective_units_by_id, {})[model.id] || model.units
    end

    def taxes
      ::CollectionSerializer.new(
        model.taxes,
        ::V1::TaxSerializer,
        collection_name: "taxes"
      ).serialize
    end
  end
end
