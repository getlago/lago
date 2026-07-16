# frozen_string_literal: true

module V1
  class PricingUnitUsageSerializer < ModelSerializer
    def serialize
      {
        lago_pricing_unit_id: model.pricing_unit_id,
        pricing_unit_code: model.pricing_unit.code,
        short_name: model.short_name,
        amount_cents: model.amount_cents,
        precise_amount_cents: model.precise_amount_cents,
        unit_amount_cents: model.unit_amount_cents,
        precise_unit_amount: model.precise_unit_amount,
        conversion_rate: model.conversion_rate
      }
    end
  end
end
