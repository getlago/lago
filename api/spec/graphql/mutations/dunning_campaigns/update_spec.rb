# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::DunningCampaigns::Update, :premium do
  let(:required_permission) { "dunning_campaigns:update" }
  let(:organization) { create(:organization, premium_integrations: ["auto_dunning"]) }
  let(:membership) { create(:membership, organization:) }
  let(:dunning_campaign) do
    create(:dunning_campaign, organization:)
  end
  let(:dunning_campaign_threshold) do
    create(:dunning_campaign_threshold, dunning_campaign:)
  end

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateDunningCampaignInput!) {
        updateDunningCampaign(input: $input) {
          id
          name
          code
          appliedToOrganization
        }
      }
    GQL
  end

  let(:input) do
    {
      id: dunning_campaign.id,
      name: "Updated Dunning campaign name",
      code: "updated-dunning-campaign-code",
      description: "Updated Dunning campaign description",
      maxAttempts: 99,
      daysBetweenAttempts: 7,
      appliedToOrganization: false,
      thresholds: [
        {
          id: dunning_campaign_threshold.id,
          amountCents: 999_00,
          currency: "USD"
        }
      ]
    }
  end

  before do
    organization.default_billing_entity.update!(applied_dunning_campaign: dunning_campaign)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "dunning_campaigns:update"

  it "updates a dunning campaign" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input:}
    )

    expect(result["data"]["updateDunningCampaign"]).to include(
      "id" => dunning_campaign.id,
      "name" => "Updated Dunning campaign name",
      "code" => "updated-dunning-campaign-code",
      "appliedToOrganization" => input[:appliedToOrganization]
    )
  end
end
