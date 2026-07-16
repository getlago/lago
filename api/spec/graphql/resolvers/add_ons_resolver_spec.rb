# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::AddOnsResolver do
  let(:required_permission) { "addons:view" }
  let(:query) do
    <<~GQL
      query {
        addOns(limit: 5) {
          collection { id name }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:add_on) { create(:add_on, organization:) }

  before { add_on }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "addons:view"

  it "returns a list of add-ons" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    add_ons_response = result["data"]["addOns"]

    expect(add_ons_response["collection"].first["id"]).to eq(add_on.id)
    expect(add_ons_response["collection"].first["name"]).to eq(add_on.name)

    expect(add_ons_response["metadata"]["currentPage"]).to eq(1)
    expect(add_ons_response["metadata"]["totalCount"]).to eq(1)
  end

  context "with integration mappings" do
    let(:integration) { create(:netsuite_integration, organization:) }
    let(:netsuite_mapping) { create(:netsuite_mapping, integration:, mappable_type: "AddOn", mappable_id: add_on.id) }
    let(:netsuite_mapping2) { create(:netsuite_mapping, external_name: "Bla") }
    let(:query) do
      <<~GQL
        query($integrationId: ID) {
          addOns(limit: 5) {
            collection { id name integrationMappings(integrationId: $integrationId) { externalId externalName } }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      integration
      netsuite_mapping
      netsuite_mapping2
    end

    it "returns a list of add-ons" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {integrationId: integration.id}
      )

      add_ons_response = result["data"]["addOns"]

      expect(add_ons_response["collection"].first["id"]).to eq(add_on.id)
      expect(add_ons_response["collection"].first["name"]).to eq(add_on.name)

      expect(add_ons_response["collection"].first["integrationMappings"].count).to eq(1)
      expect(add_ons_response["collection"].first["integrationMappings"].first["externalName"])
        .to eq("Credits and Discounts")

      expect(add_ons_response["metadata"]["currentPage"]).to eq(1)
      expect(add_ons_response["metadata"]["totalCount"]).to eq(1)
    end
  end
end
