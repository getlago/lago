# frozen_string_literal: true

module Coupons
  class TerminateService < BaseService
    Result = BaseResult[:coupon]

    def self.terminate_all_expired
      Coupon
        .active
        .time_limit
        .expired
        .find_each(&:mark_as_terminated!)
    end

    def initialize(coupon)
      @coupon = coupon
      super
    end

    def call
      return result.not_found_failure!(resource: "coupon") unless coupon

      coupon.mark_as_terminated! unless coupon.terminated?

      result.coupon = coupon
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :coupon
  end
end
