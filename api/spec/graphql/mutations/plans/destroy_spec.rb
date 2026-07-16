# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Plans::Destroy do
  subject(:graphql_request) do
    execute_query(
      query: mutation,
      input: {id: plan.id}
    )
  end

  let(:required_permission) { "plans:delete" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization: membership.organization) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyPlanInput!) {
        destroyPlan(input: $input) {
          id
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "plans:delete"

  it "marks plan as pending_deletion" do
    expect { graphql_request }.to change { plan.reload.pending_deletion }.from(false).to(true)
  end

  it "returns the deleted plan" do
    data = graphql_request["data"]["destroyPlan"]
    expect(data["id"]).to eq(plan.id)
  end
end
