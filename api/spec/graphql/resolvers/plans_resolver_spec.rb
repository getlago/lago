# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PlansResolver do
  let(:required_permission) { "plans:view" }
  let(:query) do
    <<~GQL
      query($withDeleted: Boolean) {
        plans(limit: 5, withDeleted: $withDeleted) {
          collection { id chargesCount customersCount }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:plan) { create(:plan, organization:) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  before do
    plan
    customer

    2.times do
      create(:subscription, customer:, plan:)
    end
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "plans:view"

  it "returns a list of plans" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    plans_response = result["data"]["plans"]

    expect(plans_response["collection"].count).to eq(organization.plans.count)
    expect(plans_response["collection"].first["id"]).to eq(plan.id)
    expect(plans_response["collection"].first["customersCount"]).to eq(1)

    expect(plans_response["metadata"]["currentPage"]).to eq(1)
    expect(plans_response["metadata"]["totalCount"]).to eq(1)
  end

  context "when filtering by with_deleted" do
    let(:plan) { create(:plan, organization:) }
    let(:deleted_plan) { create(:plan, organization:, deleted_at: Time.current) }

    before do
      plan
      deleted_plan
    end

    it "returns all plans including deleted ones" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {withDeleted: true}
      )

      plans_response = result["data"]["plans"]
      expect(plans_response["collection"].count).to eq(2)
      expect(plans_response["collection"].map { |p| p["id"] }).to include(plan.id, deleted_plan.id)

      expect(plans_response["metadata"]["currentPage"]).to eq(1)
      expect(plans_response["metadata"]["totalCount"]).to eq(2)
    end
  end
end
