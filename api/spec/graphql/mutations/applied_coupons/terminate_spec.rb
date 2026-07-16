# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AppliedCoupons::Terminate do
  let(:required_permission) { "coupons:detach" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:coupon) { create(:coupon, organization:) }
  let(:applied_coupon) { create(:applied_coupon, coupon:, customer:) }

  let(:mutation) do
    <<-GQL
      mutation($input: TerminateAppliedCouponInput!) {
        terminateAppliedCoupon(input: $input) {
          id terminatedAt
        }
      }
    GQL
  end

  before { applied_coupon }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:detach"

  it "terminates an applied coupon" do
    result = execute_query(
      query: mutation,
      input: {id: applied_coupon.id}
    )

    data = result["data"]["terminateAppliedCoupon"]

    expect(data["id"]).to eq(applied_coupon.id)
    expect(data["terminatedAt"]).to be_present
  end
end
