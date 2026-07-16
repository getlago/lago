# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Coupons::Create do
  let(:required_permission) { "coupons:create" }
  let(:membership) { create(:membership) }
  let(:expiration_at) { Time.current + 3.days }
  let(:plan) { create(:plan, organization: membership.organization) }
  let(:billable_metric) { create(:billable_metric, organization: membership.organization) }
  let(:mutation) do
    <<-GQL
      mutation($input: CreateCouponInput!) {
        createCoupon(input: $input) {
          id,
          name,
          code,
          description,
          amountCents,
          amountCurrency,
          expiration,
          expirationAt,
          status,
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
  it_behaves_like "requires permission", "coupons:create"

  it "creates a coupon" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          name: "Super Coupon",
          code: "free-beer",
          description: "This is a description",
          couponType: "fixed_amount",
          frequency: "once",
          amountCents: 5000,
          amountCurrency: "EUR",
          expiration: "time_limit",
          expirationAt: expiration_at.iso8601,
          reusable: false,
          appliesTo: {
            planIds: [plan.id]
          }
        }
      }
    )

    result_data = result["data"]["createCoupon"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("Super Coupon")
    expect(result_data["code"]).to eq("free-beer")
    expect(result_data["description"]).to eq("This is a description")
    expect(result_data["amountCents"]).to eq("5000")
    expect(result_data["amountCurrency"]).to eq("EUR")
    expect(result_data["expiration"]).to eq("time_limit")
    expect(result_data["expirationAt"]).to eq expiration_at.iso8601
    expect(result_data["status"]).to eq("active")
    expect(result_data["reusable"]).to eq(false)
    expect(result_data["limitedPlans"]).to eq(true)
    expect(result_data["plans"].first["id"]).to eq(plan.id)
  end

  context "with billable metric limitations" do
    let(:mutation) do
      <<-GQL
      mutation($input: CreateCouponInput!) {
        createCoupon(input: $input) {
          id,
          name,
          code,
          amountCents,
          amountCurrency,
          expiration,
          expirationAt,
          status,
          limitedBillableMetrics,
          billableMetrics {
            id
          },
          reusable
        }
      }
      GQL
    end

    it "creates a coupon" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Super Coupon",
            code: "free-beer",
            couponType: "fixed_amount",
            frequency: "once",
            amountCents: 5000,
            amountCurrency: "EUR",
            expiration: "time_limit",
            expirationAt: expiration_at.iso8601,
            reusable: false,
            appliesTo: {
              billableMetricIds: [billable_metric.id]
            }
          }
        }
      )

      result_data = result["data"]["createCoupon"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("Super Coupon")
      expect(result_data["code"]).to eq("free-beer")
      expect(result_data["amountCents"]).to eq("5000")
      expect(result_data["amountCurrency"]).to eq("EUR")
      expect(result_data["expiration"]).to eq("time_limit")
      expect(result_data["expirationAt"]).to eq expiration_at.iso8601
      expect(result_data["status"]).to eq("active")
      expect(result_data["reusable"]).to eq(false)
      expect(result_data["limitedBillableMetrics"]).to eq(true)
      expect(result_data["billableMetrics"].first["id"]).to eq(billable_metric.id)
    end
  end

  context "with an expiration date" do
    it "creates a coupon" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Super Coupon",
            code: "free-beer",
            couponType: "fixed_amount",
            frequency: "once",
            amountCents: 5000,
            amountCurrency: "EUR",
            expiration: "time_limit",
            expirationAt: expiration_at.iso8601
          }
        }
      )

      result_data = result["data"]["createCoupon"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("Super Coupon")
      expect(result_data["code"]).to eq("free-beer")
      expect(result_data["amountCents"]).to eq("5000")
      expect(result_data["amountCurrency"]).to eq("EUR")
      expect(result_data["expiration"]).to eq("time_limit")
      expect(result_data["expirationAt"]).to eq(expiration_at.iso8601)
      expect(result_data["status"]).to eq("active")
    end
  end
end
