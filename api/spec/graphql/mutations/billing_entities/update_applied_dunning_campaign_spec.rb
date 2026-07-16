# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillingEntities::UpdateAppliedDunningCampaign do
  let(:required_permission) { "billing_entities:update" }
  let(:membership) { create(:membership, organization:) }
  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:, applied_dunning_campaign:) }
  let(:dunning_campaign) { create(:dunning_campaign, organization:) }
  let(:applied_dunning_campaign) { create(:dunning_campaign, organization:) }
  let(:mutation) do
    <<~GQL
      mutation($input: BillingEntityUpdateAppliedDunningCampaignInput!) {
        billingEntityUpdateAppliedDunningCampaign(input: $input) {
          id
          appliedDunningCampaign {
            id
          }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:update"

  context "when the user has the required permission" do
    it "changes the applied dunning campaign successfully" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            appliedDunningCampaignId: dunning_campaign.id
          }
        }
      )

      data = result["data"]["billingEntityUpdateAppliedDunningCampaign"]
      expect(data["id"]).to eq(billing_entity.id.to_s)
      expect(data["appliedDunningCampaign"]["id"]).to eq(dunning_campaign.id.to_s)
    end

    it "removes the applied dunning campaign when ID is nil" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            appliedDunningCampaignId: nil
          }
        }
      )

      data = result["data"]["billingEntityUpdateAppliedDunningCampaign"]

      expect(data["id"]).to eq(billing_entity.id.to_s)
      expect(data["appliedDunningCampaign"]).to be_nil
    end
  end

  context "when the user does not have the required permission" do
    it "returns an authorization error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: [],
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            appliedDunningCampaignId: dunning_campaign.id
          }
        }
      )

      errors = result["errors"]

      expect(errors).not_to be_empty
      expect(errors.first["message"]).to eq("Missing permissions")
    end
  end

  context "when the billing entity does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            billingEntityId: "nonexistent-id",
            appliedDunningCampaignId: dunning_campaign.id
          }
        }
      )

      errors = result["errors"]

      expect(errors).not_to be_empty
      expect(errors.first["message"]).to eq("Resource not found")
    end
  end

  context "when the dunning campaign does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            appliedDunningCampaignId: "nonexistent-id"
          }
        }
      )

      errors = result["errors"]

      expect(errors).not_to be_empty
      expect(errors.first["message"]).to eq("Resource not found")
    end
  end
end
