# frozen_string_literal: true

module Mutations
  module AppliedCoupons
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:attach"

      graphql_name "CreateAppliedCoupon"
      description "Assigns a Coupon to a Customer"

      argument :coupon_id, ID, required: true
      argument :customer_id, ID, required: true

      argument :amount_cents, GraphQL::Types::BigInt, required: false
      argument :amount_currency, Types::CurrencyEnum, required: false
      argument :frequency, Types::Coupons::FrequencyEnum, required: false
      argument :frequency_duration, Integer, required: false
      argument :percentage_rate, Float, required: false

      type Types::AppliedCoupons::Object

      def resolve(**args)
        customer = current_organization.customers.find_by(id: args[:customer_id])
        coupon = current_organization.coupons.find_by(id: args[:coupon_id])

        result = ::AppliedCoupons::CreateService.call(customer:, coupon:, params: args)
        result.success? ? result.applied_coupon : result_error(result)
      end
    end
  end
end
