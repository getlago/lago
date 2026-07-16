# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::AppliedCouponSerializer do
  subject(:serializer) { described_class.new(applied_coupon, root_name: "applied_coupon", includes: %i[credits]) }

  let(:applied_coupon) { create(:applied_coupon) }
  let(:credit) { create(:credit, amount_cents: 50, applied_coupon:) }

  before { credit }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)
    credit = applied_coupon.credits.first

    expect(result["applied_coupon"]["lago_id"]).to eq(applied_coupon.id)
    expect(result["applied_coupon"]["lago_coupon_id"]).to eq(applied_coupon.coupon.id)
    expect(result["applied_coupon"]["coupon_code"]).to eq(applied_coupon.coupon.code)
    expect(result["applied_coupon"]["coupon_name"]).to eq(applied_coupon.coupon.name)
    expect(result["applied_coupon"]["coupon_description"]).to eq(applied_coupon.coupon.description)
    expect(result["applied_coupon"]["coupon_status"]).to eq(applied_coupon.coupon.status)
    expect(result["applied_coupon"]["coupon_deleted_at"]).to eq(applied_coupon.coupon.deleted_at&.iso8601)
    expect(result["applied_coupon"]["lago_customer_id"]).to eq(applied_coupon.customer.id)
    expect(result["applied_coupon"]["external_customer_id"]).to eq(applied_coupon.customer.external_id)
    expect(result["applied_coupon"]["status"]).to eq(applied_coupon.status)
    expect(result["applied_coupon"]["amount_cents"]).to eq(applied_coupon.amount_cents)
    expect(result["applied_coupon"]["amount_cents_remaining"])
      .to eq(applied_coupon.amount_cents - applied_coupon.credits.sum(:amount_cents))
    expect(result["applied_coupon"]["amount_currency"]).to eq(applied_coupon.amount_currency)
    expect(result["applied_coupon"]["percentage_rate"]).to eq(applied_coupon.percentage_rate)
    expect(result["applied_coupon"]["frequency"]).to eq(applied_coupon.frequency)
    expect(result["applied_coupon"]["frequency_duration"]).to eq(applied_coupon.frequency_duration)
    expect(result["applied_coupon"]["frequency_duration_remaining"])
      .to eq(applied_coupon.frequency_duration_remaining)
    expect(result["applied_coupon"]["expiration_at"]).to eq(applied_coupon.coupon.expiration_at&.iso8601)
    expect(result["applied_coupon"]["created_at"]).to eq(applied_coupon.created_at&.iso8601)
    expect(result["applied_coupon"]["terminated_at"]).to eq(applied_coupon.terminated_at&.iso8601)

    expect(result["applied_coupon"]["credits"].first["lago_id"]).to eq(credit.id)
    expect(result["applied_coupon"]["credits"].first["amount_cents"]).to eq(credit.amount_cents)
    expect(result["applied_coupon"]["credits"].first["amount_currency"]).to eq(credit.amount_currency)
    expect(result["applied_coupon"]["credits"].first["item"]["type"]).to eq(credit.item_type)
    expect(result["applied_coupon"]["credits"].first["item"]["code"]).to eq(credit.item_code)
    expect(result["applied_coupon"]["credits"].first["item"]["name"]).to eq(credit.item_name)
    expect(result["applied_coupon"]["credits"].first["invoice"]["payment_status"])
      .to eq(credit.invoice.payment_status)
    expect(result["applied_coupon"]["credits"].first["invoice"]["lago_id"]).to eq(credit.invoice.id)
  end
end
