# frozen_string_literal: true

module Types
  module Coupons
    class CouponTypeEnum < Types::BaseEnum
      Coupon::COUPON_TYPES.each do |type|
        value type
      end
    end
  end
end
