# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CouponResolver do
  let(:required_permission) { "coupons:view" }
  let(:query) do
    <<~GQL
      query($couponId: ID!) {
        coupon(id: $couponId) {
          id name description customersCount appliedCouponsCount expirationAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:coupon) { create(:coupon, organization:) }
  let(:applied_coupon) { create(:applied_coupon, coupon:) }

  before do
    customer
    applied_coupon

    2.times do
      create(:subscription, customer:)
    end
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:view"

  it "returns a single coupon" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {couponId: coupon.id}
    )

    coupon_response = result["data"]["coupon"]

    expect(coupon_response["id"]).to eq(coupon.id)
    expect(coupon_response["customersCount"]).to eq(1)
    expect(coupon_response["description"]).to eq(coupon.description)
    expect(coupon_response["appliedCouponsCount"]).to eq(1)
  end

  context "when plan is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {couponId: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
