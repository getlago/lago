# frozen_string_literal: true

module AppliedCoupons
  class RecreditService < BaseService
    Result = BaseResult[:applied_coupon]

    def initialize(credit:)
      @credit = credit
      @applied_coupon = credit.applied_coupon
      @invoice = credit.invoice

      super
    end

    def call
      return result.not_found_failure!(resource: "applied_coupon") if applied_coupon.nil?

      applied_coupon.with_lock do
        # If the coupon was terminated and this was the last credit that caused it to be terminated,
        # reactivate the coupon
        if applied_coupon.terminated? && should_reactivate_coupon?
          applied_coupon.status = :active
          applied_coupon.terminated_at = nil
          applied_coupon.save!
        end

        # For recurring coupons, increment the frequency_duration_remaining
        if applied_coupon.recurring?
          applied_coupon.frequency_duration_remaining += 1
          applied_coupon.save!
        end
      end

      result.applied_coupon = applied_coupon
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :credit, :applied_coupon, :invoice

    def should_reactivate_coupon?
      # Forever coupons don't need to be reactivated
      return false if applied_coupon.forever?
      # Check if the original coupon is still active
      return false if applied_coupon.coupon.terminated?
      # For both once and recurring coupons, we can reactivate them if they're terminated
      # since they would have been terminated due to usage
      true
    end
  end
end
