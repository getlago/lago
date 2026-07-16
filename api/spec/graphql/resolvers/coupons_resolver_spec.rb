# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CouponsResolver do
  let(:required_permission) { "coupons:view" }
  let(:query) do
    <<~GQL
      query {
        coupons(limit: 5, status: active) {
          collection { id }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:coupon) { create(:coupon, organization:) }

  before do
    coupon

    create(:coupon, organization:, status: :terminated)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "coupons:view"

  it "returns a list of coupons" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    coupons_response = result["data"]["coupons"]

    expect(coupons_response["collection"].count).to eq(organization.coupons.active.count)
    expect(coupons_response["collection"].first["id"]).to eq(coupon.id)

    expect(coupons_response["metadata"]["currentPage"]).to eq(1)
    expect(coupons_response["metadata"]["totalCount"]).to eq(1)
  end
end
