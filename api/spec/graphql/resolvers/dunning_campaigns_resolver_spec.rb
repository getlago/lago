# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DunningCampaignsResolver do
  let(:required_permission) { "dunning_campaigns:view" }
  let(:query) do
    <<~GQL
      query {
        dunningCampaigns(limit: 5) {
          collection { id name }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:dunning_campaign) { create(:dunning_campaign, organization:) }

  before { dunning_campaign }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "dunning_campaigns:view"

  it "returns a list of dunning campaigns" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    dunning_campaigns_response = result["data"]["dunningCampaigns"]

    expect(dunning_campaigns_response["collection"].first).to include(
      "id" => dunning_campaign.id,
      "name" => dunning_campaign.name
    )

    expect(dunning_campaigns_response["metadata"]).to include(
      "currentPage" => 1,
      "totalCount" => 1
    )
  end

  context "when filtering by threshold currency" do
    let(:query) do
      <<~GQL
        query {
          dunningCampaigns(limit: 5, currency: [EUR]) {
            collection { id name }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      create(:dunning_campaign, organization:)
      create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR")
    end

    it "returns all dunning campaigns with currency threshold" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      dunning_campaigns_response = result["data"]["dunningCampaigns"]

      expect(dunning_campaigns_response["collection"].first).to include(
        "id" => dunning_campaign.id,
        "name" => dunning_campaign.name
      )

      expect(dunning_campaigns_response["metadata"]).to include(
        "currentPage" => 1,
        "totalCount" => 1
      )
    end
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(current_user: membership.user, query:)

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when not member of the organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: create(:organization),
        permissions: required_permission,
        query:
      )

      expect_graphql_error(result:, message: "Not in organization")
    end
  end
end
