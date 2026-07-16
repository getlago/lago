# frozen_string_literal: true

namespace :applied_coupons do
  desc "Populate frequency duration remaining field"
  task populate_frequency_duration_remaining: :environment do
    AppliedCoupon.find_each do |applied_coupon|
      next unless applied_coupon.recurring?

      applied_coupon.frequency_duration_remaining = applied_coupon.frequency_duration
      applied_coupon.save!
    end
  end
end
