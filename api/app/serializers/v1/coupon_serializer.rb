# frozen_string_literal: true

module V1
  class CouponSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        name: model.name,
        code: model.code,
        description: model.description,
        coupon_type: model.coupon_type,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        percentage_rate: model.percentage_rate,
        frequency: model.frequency,
        frequency_duration: model.frequency_duration,
        reusable: model.reusable,
        limited_plans: model.limited_plans,
        limited_billable_metrics: model.limited_billable_metrics,
        plan_codes: model.plans.parents.pluck(:code),
        billable_metric_codes: model.billable_metrics.pluck(:code),
        created_at: model.created_at.iso8601,
        expiration: model.expiration,
        expiration_at: model.expiration_at&.iso8601,
        terminated_at: model.terminated_at&.iso8601
      }
    end
  end
end
