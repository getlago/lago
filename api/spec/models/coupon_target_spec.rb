# frozen_string_literal: true

RSpec.describe CouponTarget do
  subject(:coupon_target) { build(:coupon_plan) }

  it { is_expected.to belong_to(:organization) }
end
