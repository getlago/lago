# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::AppliedCouponsResolver do
  let(:required_permission) { "coupons:view" }
  let(:query) do
    <<~GQL
      query {
        appliedCoupons(limit: 5, status: active) {
          collection { id amountCents amountCurrency frequency }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:coupon) { create(:coupon, organization:) }
  let(:applied_coupon) { create(:applied_coupon, customer:, coupon:, organization:) }

  before do
    applied_coupon

    create(:applied_coupon, customer:, coupon:, organization:, status: :terminated)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:view"

  it "returns a list of applied coupons" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    applied_coupons_response = result["data"]["appliedCoupons"]

    expect(applied_coupons_response["collection"].count).to eq(1)
    expect(applied_coupons_response["collection"].first["id"]).to eq(applied_coupon.id)

    expect(applied_coupons_response["metadata"]["currentPage"]).to eq(1)
    expect(applied_coupons_response["metadata"]["totalCount"]).to eq(1)
  end

  context "with external_customer_id filter" do
    let(:query) do
      <<~GQL
        query($externalCustomerId: String) {
          appliedCoupons(externalCustomerId: $externalCustomerId, limit: 5) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:other_customer) { create(:customer, organization:) }

    before do
      create(:applied_coupon, customer: other_customer, coupon:, organization:)
    end

    it "filters by external customer id" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {externalCustomerId: customer.external_id}
      )

      applied_coupons_response = result["data"]["appliedCoupons"]

      expect(applied_coupons_response["metadata"]["totalCount"]).to eq(2)
      expect(applied_coupons_response["collection"].pluck("id")).to include(applied_coupon.id)
    end
  end

  context "with coupon_code filter" do
    let(:query) do
      <<~GQL
        query($couponCode: [String!]) {
          appliedCoupons(couponCode: $couponCode, limit: 5) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:other_coupon) { create(:coupon, organization:) }

    before do
      create(:applied_coupon, customer:, coupon: other_coupon, organization:)
    end

    it "filters by coupon code" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {couponCode: [coupon.code]}
      )

      applied_coupons_response = result["data"]["appliedCoupons"]

      expect(applied_coupons_response["metadata"]["totalCount"]).to eq(2)
      expect(applied_coupons_response["collection"].pluck("id")).to include(applied_coupon.id)
    end
  end
end
