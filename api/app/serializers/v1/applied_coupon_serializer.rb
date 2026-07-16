# frozen_string_literal: true

module V1
  class AppliedCouponSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_coupon_id: model.coupon.id,
        coupon_code: model.coupon.code,
        coupon_name: model.coupon.name,
        coupon_description: model.coupon.description,
        coupon_status: model.coupon.status,
        coupon_deleted_at: model.coupon.deleted_at&.iso8601,
        lago_customer_id: model.customer.id,
        external_customer_id: model.customer.external_id,
        status: model.status,
        amount_cents: model.amount_cents,
        amount_cents_remaining:,
        amount_currency: model.amount_currency,
        percentage_rate: model.percentage_rate,
        frequency: model.frequency,
        frequency_duration: model.frequency_duration,
        frequency_duration_remaining: model.frequency_duration_remaining,
        expiration_at: model.coupon.expiration_at&.iso8601,
        created_at: model.created_at.iso8601,
        terminated_at: model.terminated_at&.iso8601
      }

      payload = payload.merge(credits) if include?(:credits)

      payload
    end

    private

    def amount_cents_remaining
      return nil if model.recurring? || model.forever?
      return nil if model.coupon.percentage?

      model.amount_cents - model.credits.active.sum(:amount_cents)
    end

    def credits
      ::CollectionSerializer.new(model.credits, ::V1::CreditSerializer, collection_name: "credits").serialize
    end
  end
end
