# frozen_string_literal: true

module V1
  class ChargeSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_billable_metric_id: model.billable_metric_id,
        code: model.code,
        invoice_display_name: model.invoice_display_name,
        billable_metric_code: model.billable_metric.code,
        created_at: model.created_at.iso8601,
        charge_model: model.charge_model,
        invoiceable: model.invoiceable,
        regroup_paid_fees: model.regroup_paid_fees,
        pay_in_advance: model.pay_in_advance,
        prorated: model.prorated,
        min_amount_cents: model.min_amount_cents,
        accepts_target_wallet: model.accepts_target_wallet,
        properties:,
        applied_pricing_unit:,
        lago_parent_id: model.parent_id
      }

      payload.merge!(charge_filters)
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

    def charge_filters
      filters = if model.filters.loaded?
        model.filters
      else
        model.filters.includes(:charge, values: :billable_metric_filter)
      end

      ::CollectionSerializer.new(
        filters,
        ::V1::ChargeFilterSerializer,
        collection_name: "filters"
      ).serialize
    end

    def applied_pricing_unit
      return if model.applied_pricing_unit.nil?

      {
        conversion_rate: model.applied_pricing_unit.conversion_rate,
        code: model.pricing_unit.code
      }
    end

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
