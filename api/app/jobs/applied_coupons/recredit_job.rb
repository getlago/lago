# frozen_string_literal: true

module AppliedCoupons
  class RecreditJob < ApplicationJob
    queue_as "default"

    def perform(credit)
      return if credit.applied_coupon.nil?

      AppliedCoupons::RecreditService.call!(credit:)
    end
  end
end
