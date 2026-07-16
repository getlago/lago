# frozen_string_literal: true

module V1
  class OrderSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        number: model.number,
        status: model.status,
        order_type: model.order_type,
        execution_mode: model.execution_mode,
        billing_snapshot: model.billing_snapshot,
        currency: model.currency,
        executed_at: model.executed_at&.iso8601,
        lago_organization_id: model.organization_id,
        lago_customer_id: model.customer_id,
        lago_order_form_id: model.order_form_id,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }
    end
  end
end
