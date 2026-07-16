# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BillingEntityTaxesResolver do
  let(:query) do
    <<~GQL
      query($billing_entity_id: ID!) {
        billingEntityTaxes(billingEntityId: $billing_entity_id) {
          collection {
            id
            code
            name
            rate
            description
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:tax1) { create(:tax, organization: organization) }
  let(:tax2) { create(:tax, organization: organization) }

  before do
    create(:billing_entity_applied_tax, billing_entity:, tax: tax1, organization:)
    create(:billing_entity_applied_tax, billing_entity:, tax: tax2, organization:)
  end

  it "returns billing entity taxes" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: ["billing_entities:view"],
      query:,
      variables: {billing_entity_id: billing_entity.id}
    )

    taxes_data = result["data"]["billingEntityTaxes"]["collection"]
    expect(taxes_data.count).to eq(2)
    expect(taxes_data.map { |t| t["id"] }).to include(tax1.id, tax2.id)
  end

  it "returns error if billing entity is not found" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: ["billing_entities:view"],
      query:,
      variables: {billing_entity_id: "invalid"}
    )

    expect_graphql_error(result:, message: "Resource not found")
  end
end
