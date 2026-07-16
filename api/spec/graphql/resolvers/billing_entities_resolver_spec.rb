# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BillingEntitiesResolver do
  let(:required_permission) { "billing_entities:view" }
  let(:query) do
    <<~GQL
      query {
        billingEntities {
          collection {
            id
            name
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity1) { organization.default_billing_entity }
  let(:billing_entity2) { create(:billing_entity, organization:) }

  before do
    billing_entity1
    billing_entity2
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:view"

  it "returns a list of billing entities" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    result_data = result["data"]["billingEntities"]
    expect(result_data["collection"].count).to eq(organization.billing_entities.count)
    expect(result_data["collection"].map { |be| be["id"] }).to match_array([billing_entity1.id, billing_entity2.id])
  end
end
