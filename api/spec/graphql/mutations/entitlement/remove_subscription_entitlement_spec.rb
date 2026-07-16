# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Entitlement::RemoveSubscriptionEntitlement, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:organization) { create(:organization) }

  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, plan:) }
  let(:privilege) { create(:privilege, feature:, code: "max") }

  let(:query) do
    <<~GQL
      mutation($input: RemoveSubscriptionEntitlementInput!) {
        removeSubscriptionEntitlement(input: $input) {
          featureCode
        }
      }
    GQL
  end

  let(:input) do
    {
      subscriptionId: subscription.id,
      featureCode: feature.code
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:update"

  context "when feature wasn't available in subscription" do
    it "removes the feature" do
      result = subject
      expect(result["data"]["removeSubscriptionEntitlement"]["featureCode"]).to eq "seats"

      sub_entitlements = Entitlement::SubscriptionEntitlement.for_subscription(subscription)
      expect(sub_entitlements.map(&:code)).not_to include("seats")
    end
  end

  context "when feature belongs to the plan" do
    let(:plan_entitlement) { create(:entitlement, feature:, plan:) }
    let(:plan_entitlement_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege:, value: "10") }

    before do
      plan_entitlement_value
    end

    it "creates a FeatureRemoval model" do
      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).map(&:code)).to include("seats")
      result = subject
      expect(result["data"]["removeSubscriptionEntitlement"]["featureCode"]).to eq "seats"
      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription)).to be_empty

      expect(Entitlement::SubscriptionFeatureRemoval.where(subscription:, feature:)).to exist
    end
  end

  context "when feature is not in plan but belongs to the subscription" do
    let(:sub_entitlement) { create(:entitlement, feature:, plan: nil, subscription:) }
    let(:sub_entitlement_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege:, value: "99") }

    before do
      sub_entitlement_value
    end

    it "removes the subscription entitlement" do
      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).map(&:code)).to include("seats")
      result = subject
      expect(result["data"]["removeSubscriptionEntitlement"]["featureCode"]).to eq "seats"

      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription)).to be_empty

      expect(sub_entitlement_value.reload).to be_discarded
      expect(sub_entitlement.reload).to be_discarded
      expect(Entitlement::SubscriptionFeatureRemoval.where(subscription:, feature:)).to be_empty
    end
  end

  context "when feature is in plan and there was subscription override" do
    let(:plan_entitlement) { create(:entitlement, feature:, plan:) }
    let(:plan_entitlement_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege:, value: "10") }
    let(:sub_entitlement) { create(:entitlement, feature:, plan: nil, subscription:) }
    let(:sub_entitlement_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege:, value: "99") }

    before do
      plan_entitlement_value
      sub_entitlement_value
    end

    it "removes the subscription entitlement and add a FeatureRemoval" do
      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).map(&:code)).to include("seats")
      result = subject
      expect(result["data"]["removeSubscriptionEntitlement"]["featureCode"]).to eq "seats"

      expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription)).to be_empty

      expect(sub_entitlement_value.reload).to be_discarded
      expect(sub_entitlement.reload).to be_discarded
      expect(Entitlement::SubscriptionFeatureRemoval.where(subscription:, feature:)).to exist
    end
  end

  context "when subscription does not exist" do
    let(:input) do
      {
        subscriptionId: "non-existent-id",
        featureCode: feature.code
      }
    end

    it "returns not found error" do
      expect_graphql_error(result: subject, message: "not_found")
    end
  end

  context "when feature does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        featureCode: "not_existing"
      }
    end

    it "returns not found error" do
      expect_graphql_error(result: subject, message: "not_found")
    end
  end
end
