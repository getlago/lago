# frozen_string_literal: true

module V1
  class PaymentMethodSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        is_default: model.is_default,
        payment_provider_code: model.payment_provider&.code,
        payment_provider_name: model.payment_provider&.name,
        payment_provider_type: model.payment_provider_type,
        provider_method_id: model.provider_method_id,
        created_at: model.created_at.iso8601
      }
    end
  end
end
