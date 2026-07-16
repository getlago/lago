# frozen_string_literal: true

FactoryBot.define do
  factory :coupon_plan, class: "CouponTarget" do
    coupon
    plan
    organization { plan&.organization || coupon&.organization || association(:organization) }
  end

  factory :coupon_billable_metric, class: "CouponTarget" do
    coupon
    billable_metric
    organization { billable_metric&.organization || coupon&.organization || association(:organization) }
  end
end
