# frozen_string_literal: true

module Types
  module Coupons
    class CreateInput < Types::BaseInputObject
      graphql_name "CreateCouponInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: false
      argument :amount_currency, Types::CurrencyEnum, required: false
      argument :code, String, required: true
      argument :coupon_type, Types::Coupons::CouponTypeEnum, required: true
      argument :description, String, required: false
      argument :frequency, Types::Coupons::FrequencyEnum, required: true
      argument :frequency_duration, Integer, required: false
      argument :name, String, required: true
      argument :percentage_rate, Float, required: false
      argument :reusable, Boolean, required: false

      argument :applies_to, Types::Coupons::LimitationInput, required: false

      argument :expiration, Types::Coupons::ExpirationEnum, required: true
      argument :expiration_at, GraphQL::Types::ISO8601DateTime, required: false
    end
  end
end
