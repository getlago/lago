# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::DunningCampaigns::Destroy, :premium do
  let(:required_permissions) { "dunning_campaigns:delete" }
  let(:membership) { create(:membership, organization:) }
  let(:organization) { create(:organization, premium_integrations: ["auto_dunning"]) }
  let(:dunning_campaign) { create(:dunning_campaign, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyDunningCampaignInput!) {
        destroyDunningCampaign(input: $input) {
          id
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "dunning_campaigns:delete"

  it "deletes a dunning campaign" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permissions,
      query: mutation,
      variables: {
        input: {id: dunning_campaign.id}
      }
    )

    data = result["data"]["destroyDunningCampaign"]
    expect(data["id"]).to eq(dunning_campaign.id)
  end

  context "when dunnign campaign is not found" do
    let(:dunning_campaign) { create(:dunning_campaign) }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permissions,
        query: mutation,
        variables: {
          input: {id: dunning_campaign.id}
        }
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
