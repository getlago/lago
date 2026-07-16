# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AppliedCoupons::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:coupon).of_type("Coupon!")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum")
    expect(subject).to have_field(:amount_cents_remaining).of_type("BigInt")
    expect(subject).to have_field(:frequency).of_type("CouponFrequency!")
    expect(subject).to have_field(:frequency_duration).of_type("Int")
    expect(subject).to have_field(:frequency_duration_remaining).of_type("Int")
    expect(subject).to have_field(:percentage_rate).of_type("Float")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:terminated_at).of_type("ISO8601DateTime")
  end
end
