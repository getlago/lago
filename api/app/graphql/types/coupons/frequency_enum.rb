# frozen_string_literal: true

module Types
  module Coupons
    class FrequencyEnum < Types::BaseEnum
      graphql_name "CouponFrequency"

      Coupon::FREQUENCIES.each do |type|
        value type
      end
    end
  end
end
