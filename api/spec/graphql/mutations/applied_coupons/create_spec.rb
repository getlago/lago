# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AppliedCoupons::Create do
  let(:required_permission) { "coupons:attach" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:mutation) do
    <<-GQL
      mutation($input: CreateAppliedCouponInput!) {
        createAppliedCoupon(input: $input) {
          coupon { id }
          id,
          amountCents,
          amountCurrency,
          createdAt
        }
      }
    GQL
  end

  let(:coupon) { create(:coupon, organization:) }
  let(:customer) { create(:customer, organization:) }

  before do
    create(:subscription, customer:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:attach"

  it "assigns a coupon to the customer" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          couponId: coupon.id,
          customerId: customer.id,
          frequency: "once",
          amountCents: 123,
          amountCurrency: "EUR"
        }
      }
    )

    result_data = result["data"]["createAppliedCoupon"]

    expect(result_data["id"]).to be_present
    expect(result_data["coupon"]["id"]).to eq(coupon.id)
    expect(result_data["amountCents"]).to eq("123")
    expect(result_data["amountCurrency"]).to eq("EUR")
    expect(result_data["createdAt"]).to be_present
  end
end
