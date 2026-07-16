# frozen_string_literal: true

module V1
  class BillableMetricSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        name: model.name,
        code: model.code,
        description: model.description,
        aggregation_type: model.aggregation_type,
        weighted_interval: model.weighted_interval,
        recurring: model.recurring,
        rounding_function: model.rounding_function,
        rounding_precision: model.rounding_precision,
        created_at: model.created_at.iso8601,
        field_name: model.field_name,
        expression: model.expression
      }

      payload.merge!(counters) if include?(:counters)
      payload.merge!(filters)

      payload
    end

    private

    def counters
      {
        active_subscriptions_count: 0,
        draft_invoices_count: 0,
        plans_count: 0
      }
    end

    def filters
      ::CollectionSerializer.new(
        model.filters,
        ::V1::BillableMetricFilterSerializer,
        collection_name: "filters"
      ).serialize
    end
  end
end
