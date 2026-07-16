# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Coupons::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:organization).of_type("Organization")
    expect(subject).to have_field(:amount_cents).of_type("BigInt")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:coupon_type).of_type("CouponTypeEnum!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:frequency).of_type("CouponFrequency!")
    expect(subject).to have_field(:frequency_duration).of_type("Int")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:percentage_rate).of_type("Float")
    expect(subject).to have_field(:reusable).of_type("Boolean!")
    expect(subject).to have_field(:status).of_type("CouponStatusEnum!")
    expect(subject).to have_field(:expiration).of_type("CouponExpiration!")
    expect(subject).to have_field(:expiration_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:activity_logs).of_type("[ActivityLog!]")
    expect(subject).to have_field(:billable_metrics).of_type("[BillableMetric!]")
    expect(subject).to have_field(:limited_billable_metrics).of_type("Boolean!")
    expect(subject).to have_field(:limited_plans).of_type("Boolean!")
    expect(subject).to have_field(:plans).of_type("[Plan!]")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:terminated_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:applied_coupons_count).of_type("Int!")
    expect(subject).to have_field(:customers_count).of_type("Int!")
  end

  describe "#plans" do
    subject { run_graphql_field("Coupon.plans", coupon) }

    let(:coupon_plan) { create(:coupon_plan) }
    let(:coupon) { coupon_plan.coupon }
    let(:parent_plan) { coupon_plan.plan }

    before do
      create(:coupon_plan, coupon:, plan: create(:plan, parent: parent_plan, code: parent_plan.code))
    end

    context "when coupon has multiple plans" do
      it "only list parent plans" do
        expect(coupon.plans.count).to eq(2)
        expect(subject).to be_present
        expect(subject).to eq([parent_plan])
      end
    end
  end
end
