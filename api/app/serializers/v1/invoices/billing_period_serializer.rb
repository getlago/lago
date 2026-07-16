# frozen_string_literal: true

module V1
  module Invoices
    class BillingPeriodSerializer < ModelSerializer
      def serialize
        {
          lago_subscription_id: model.subscription_id,
          external_subscription_id: model.subscription&.external_id,
          lago_plan_id: model.subscription&.plan_id,
          subscription_from_datetime: model.from_datetime&.iso8601,
          subscription_to_datetime: model.to_datetime&.iso8601,
          charges_from_datetime: model.charges_from_datetime&.iso8601,
          charges_to_datetime: model.charges_to_datetime&.iso8601,
          fixed_charges_from_datetime: model.fixed_charges_from_datetime&.iso8601,
          fixed_charges_to_datetime: model.fixed_charges_to_datetime&.iso8601,
          invoicing_reason: model.invoicing_reason
        }
      end
    end
  end
end
