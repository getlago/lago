# frozen_string_literal: true

module Types
  module AppliedCoupons
    class StatusEnum < Types::BaseEnum
      graphql_name "AppliedCouponStatusEnum"

      AppliedCoupon::STATUSES.each do |type|
        value type
      end
    end
  end
end
