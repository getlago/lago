# frozen_string_literal: true

module Coupons
  class DestroyService < BaseService
    Result = BaseResult[:coupon]

    def initialize(coupon:)
      @coupon = coupon
      super
    end

    activity_loggable(
      action: "coupon.deleted",
      record: -> { coupon }
    )

    def call
      return result.not_found_failure!(resource: "coupon") unless coupon

      ActiveRecord::Base.transaction do
        coupon.discard!
        coupon.coupon_targets.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

        coupon.applied_coupons.active.find_each do |applied_coupon|
          AppliedCoupons::TerminateService.call(applied_coupon:)
        end
      end

      result.coupon = coupon
      result
    end

    private

    attr_reader :coupon
  end
end
