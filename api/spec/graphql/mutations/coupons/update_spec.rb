# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Coupons::Update do
  let(:required_permission) { "coupons:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:coupon) { create(:coupon, organization:) }
  let(:expiration_at) { Time.current + 3.days }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:mutation) do
    <<-GQL
      mutation($input: UpdateCouponInput!) {
        updateCoupon(input: $input) {
          id,
          name,
          code,
          description
          status,
          amountCents,
          amountCurrency,
          expiration,
          expirationAt,
          limitedPlans,
          plans {
            id
          },
          reusable
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:update"

  it "updates a coupon" do
    result = execute_query(
      query: mutation,
      input: {
        id: coupon.id,
        name: "New name",
        couponType: "fixed_amount",
        frequency: "once",
        code: "new_code",
        description: "This is a description",
        amountCents: 123,
        amountCurrency: "USD",
        expiration: "time_limit",
        expirationAt: expiration_at.iso8601,
        reusable: false,
        appliesTo: {
          planIds: [plan.id]
        }
      }
    )

    result_data = result["data"]["updateCoupon"]

    expect(result_data["name"]).to eq("New name")
    expect(result_data["code"]).to eq("new_code")
    expect(result_data["description"]).to eq("This is a description")
    expect(result_data["status"]).to eq("active")
    expect(result_data["amountCents"]).to eq("123")
    expect(result_data["amountCurrency"]).to eq("USD")
    expect(result_data["expiration"]).to eq("time_limit")
    expect(result_data["expirationAt"]).to eq expiration_at.iso8601
    expect(result_data["reusable"]).to eq(false)
    expect(result_data["limitedPlans"]).to eq(true)
    expect(result_data["plans"].first["id"]).to eq(plan.id)
  end

  context "with billable metric limitations" do
    let(:mutation) do
      <<-GQL
      mutation($input: UpdateCouponInput!) {
        updateCoupon(input: $input) {
          id,
          name,
          code,
          status,
          amountCents,
          amountCurrency,
          expiration,
          expirationAt,
          limitedBillableMetrics,
          billableMetrics {
            id
          },
          reusable
        }
      }
      GQL
    end

    it "updates a coupon" do
      result = execute_query(
        query: mutation,
        input: {
          id: coupon.id,
          name: "New name",
          couponType: "fixed_amount",
          frequency: "once",
          code: "new_code",
          amountCents: 123,
          amountCurrency: "USD",
          expiration: "time_limit",
          expirationAt: expiration_at.iso8601,
          reusable: false,
          appliesTo: {
            billableMetricIds: [billable_metric.id]
          }
        }
      )

      result_data = result["data"]["updateCoupon"]

      expect(result_data["name"]).to eq("New name")
      expect(result_data["code"]).to eq("new_code")
      expect(result_data["status"]).to eq("active")
      expect(result_data["amountCents"]).to eq("123")
      expect(result_data["amountCurrency"]).to eq("USD")
      expect(result_data["expiration"]).to eq("time_limit")
      expect(result_data["expirationAt"]).to eq expiration_at.iso8601
      expect(result_data["reusable"]).to eq(false)
      expect(result_data["limitedBillableMetrics"]).to eq(true)
      expect(result_data["billableMetrics"].first["id"]).to eq(billable_metric.id)
    end
  end
end
