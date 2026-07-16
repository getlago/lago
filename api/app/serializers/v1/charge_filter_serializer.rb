# frozen_string_literal: true

module V1
  class ChargeFilterSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        charge_code: model.charge.code,
        invoice_display_name: model.invoice_display_name,
        properties:,
        values: model.to_h
      }
    end

    private

    # TODO(pricing_group_keys): remove after deprecation of grouped_by
    def properties
      attributes = model.properties
      if attributes["grouped_by"].present? && attributes["pricing_group_keys"].blank?
        attributes["pricing_group_keys"] = attributes["grouped_by"]
      end

      if attributes["pricing_group_keys"].present? && attributes["grouped_by"].blank?
        attributes["grouped_by"] = attributes["pricing_group_keys"]
      end

      attributes
    end
  end
end
