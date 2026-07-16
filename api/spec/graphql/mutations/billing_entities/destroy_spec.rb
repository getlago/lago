# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillingEntities::Destroy do
  let(:required_permission) { "billing_entities:delete" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:mutation) do
    <<~GQL
      mutation($input: DestroyBillingEntityInput!) {
        destroyBillingEntity(input: $input) {
          code
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:delete"

  # We're not allowing now to destroy a billing entity, but this endpoint is needed for FE
  it "returns default billing entity for the current organization" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          code: organization.default_billing_entity.code
        }
      }
    )

    result_data = result["data"]["destroyBillingEntity"]
    expect(result_data["code"]).to eq(organization.default_billing_entity.code)
    expect(organization.default_billing_entity.deleted_at).to be_nil
  end
end
