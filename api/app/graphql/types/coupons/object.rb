# frozen_string_literal: true

module Types
  module Coupons
    class Object < Types::BaseObject
      graphql_name "Coupon"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType

      field :amount_cents, GraphQL::Types::BigInt, null: true
      field :amount_currency, Types::CurrencyEnum, null: true
      field :code, String, null: false
      field :coupon_type, Types::Coupons::CouponTypeEnum, null: false
      field :description, String, null: true
      field :frequency, Types::Coupons::FrequencyEnum, null: false
      field :frequency_duration, Integer, null: true
      field :name, String, null: false
      field :percentage_rate, Float, null: true
      field :reusable, Boolean, null: false
      field :status, Types::Coupons::StatusEnum, null: false

      field :expiration, Types::Coupons::ExpirationEnum, null: false
      field :expiration_at, GraphQL::Types::ISO8601DateTime, null: true

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :billable_metrics, [Types::BillableMetrics::Object]
      field :limited_billable_metrics, Boolean, null: false
      field :limited_plans, Boolean, null: false
      field :plans, [Types::Plans::Object]

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :terminated_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :applied_coupons_count, Integer, null: false
      field :customers_count, Integer, null: false, description: "Number of customers using this coupon"

      def customers_count
        object.applied_coupons.active.select(:customer_id).distinct.count
      end

      def applied_coupons_count
        object.applied_coupons.count
      end

      def plans
        object.plans.parents
      end
    end
  end
end
