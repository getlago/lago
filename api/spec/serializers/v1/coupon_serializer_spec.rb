# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CouponSerializer do
  subject(:serializer) { described_class.new(coupon, root_name: "coupon") }

  let(:coupon_plan) { create(:coupon_plan) }
  let(:coupon) { coupon_plan.coupon }

  before { coupon_plan }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["coupon"]["lago_id"]).to eq(coupon.id)
    expect(result["coupon"]["name"]).to eq(coupon.name)
    expect(result["coupon"]["code"]).to eq(coupon.code)
    expect(result["coupon"]["description"]).to eq(coupon.description)
    expect(result["coupon"]["amount_cents"]).to eq(coupon.amount_cents)
    expect(result["coupon"]["amount_currency"]).to eq(coupon.amount_currency)
    expect(result["coupon"]["limited_plans"]).to eq(coupon.limited_plans)
    expect(result["coupon"]["limited_billable_metrics"]).to eq(coupon.limited_billable_metrics)
    expect(result["coupon"]["expiration"]).to eq(coupon.expiration)
    expect(result["coupon"]["expiration_at"]).to eq(coupon.expiration_at&.iso8601)
    expect(result["coupon"]["created_at"]).to eq(coupon.created_at.iso8601)
    expect(result["coupon"]["terminated_at"]).to eq(coupon.terminated_at&.iso8601)
    expect(result["coupon"]["plan_codes"].first).to eq(coupon_plan.plan.code)
    expect(result["coupon"]["billable_metric_codes"]).to eq([])
  end

  context "when plan has childs" do
    before do
      child_plan = create(:plan, parent: coupon_plan.plan, code: coupon_plan.plan.code)
      create(:coupon_plan, coupon:, plan: child_plan)
    end

    it "only list parent plans" do
      result = JSON.parse(serializer.to_json)

      expect(result["coupon"]["plan_codes"]).to eq([coupon_plan.plan.code])
    end
  end
end
