# frozen_string_literal: true

namespace :coupons do
  desc "Populate expiration_date for coupons"
  task fill_expiration_date: :environment do
    Coupon.unscoped.find_each do |coupon|
      next unless coupon.expiration_duration

      expiration_date = coupon.created_at.to_date + coupon.expiration_duration.days
      coupon.update!(expiration_date:)
    end
  end
end
