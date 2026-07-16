# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Entitlement::CreateOrUpdateSubscriptionEntitlement, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:organization) { create(:organization) }

  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, plan:) }
  let(:feature) { create(:feature, organization:, code: "seats", name: "SEATS") }
  let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
  let(:privilege2) { create(:privilege, feature:, code: "reset", value_type: "select", config: {select_options: %w[email slack]}) }

  let(:query) do
    <<~GQL
      mutation($input: CreateOrUpdateSubscriptionEntitlementInput!) {
        createOrUpdateSubscriptionEntitlement(input: $input) {
          code
          name
          privileges { code value valueType }
        }
      }
    GQL
  end

  let(:input) do
    {
      subscriptionId: subscription.id,
      entitlement: {
        featureCode: feature.code,
        privileges: [
          {privilegeCode: privilege.code, value: "100"}
        ]
      }
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:update"

  context "when feature is not on plan nor on subscription" do
    it "adds the feature to the subscription" do
      result = subject

      result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
      expect(result_data).to eq({
        "code" => "seats",
        "name" => "SEATS",
        "privileges" => [
          {
            "code" => "max",
            "value" => "100",
            "valueType" => "integer"
          }
        ]
      })
    end
  end

  context "when feature is on plan but not the privilege" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        entitlement: {
          featureCode: feature.code,
          privileges: [
            {privilegeCode: privilege.code, value: "2"},
            {privilegeCode: privilege2.code, value: "slack"}
          ]
        }
      }
    end

    it "add new privilege" do
      entitlement = create(:entitlement, plan:, feature:)
      create(:entitlement_value, entitlement:, privilege:, value: "2")

      result = subject

      result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
      expect(result_data).to eq({
        "code" => "seats",
        "name" => "SEATS",
        "privileges" => [
          {
            "code" => "max",
            "value" => "2",
            "valueType" => "integer"
          },
          {
            "code" => "reset",
            "value" => "slack",
            "valueType" => "select"
          }
        ]
      })
    end
  end

  context "when removing privileges from the subscription" do
    let(:plan_entitlement) { create(:entitlement, plan:, feature:) }

    let(:input) do
      {
        subscriptionId: subscription.id,
        entitlement: {
          featureCode: feature.code,
          privileges: [
            {privilegeCode: privilege.code, value: "100"}
          ]
        }
      }
    end

    before do
      create(:entitlement_value, entitlement: plan_entitlement, privilege:, value: "2")
    end

    context "when privileges is from the plan" do
      it "removes the privileges" do
        create(:entitlement_value, entitlement: plan_entitlement, privilege: privilege2, value: "email")

        result = subject
        result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
        expect(result_data).to eq({
          "code" => "seats",
          "name" => "SEATS",
          "privileges" => [
            {
              "code" => "max",
              "value" => "100",
              "valueType" => "integer"
            }
          ]
        })
      end
    end

    context "when privileges is from the plan and is already removed" do
      it "removes the privileges" do
        create(:entitlement_value, entitlement: plan_entitlement, privilege: privilege2, value: "email")
        create(:subscription_feature_removal, subscription:, privilege: privilege2)

        result = subject
        result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
        expect(result_data).to eq({
          "code" => "seats",
          "name" => "SEATS",
          "privileges" => [
            {
              "code" => "max",
              "value" => "100",
              "valueType" => "integer"
            }
          ]
        })
      end
    end

    context "when privileges is from the plan. was removed but is restored" do
      let(:input) do
        {
          subscriptionId: subscription.id,
          entitlement: {
            featureCode: feature.code,
            privileges: [
              {privilegeCode: privilege.code, value: value}
            ]
          }
        }
      end

      before do
        # create(:entitlement_value, entitlement: plan_entitlement, privilege: privilege2, value: "email")
        create(:subscription_feature_removal, subscription:, privilege: privilege, deleted_at: 1.day.ago)
        create(:subscription_feature_removal, subscription:, privilege: privilege)
      end

      context "when the value is the same as plan" do
        let(:value) { "2" }

        it "restores the privilege" do
          result = subject
          result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
          expect(result_data).to eq({
            "code" => "seats",
            "name" => "SEATS",
            "privileges" => [
              {
                "code" => "max",
                "value" => "2",
                "valueType" => "integer"
              }
            ]
          })
        end
      end

      context "when the value is different from plan" do
        let(:value) { "100" }

        it "restores the privilege with an override" do
          result = subject
          result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
          expect(result_data).to eq({
            "code" => "seats",
            "name" => "SEATS",
            "privileges" => [
              {
                "code" => "max",
                "value" => "100",
                "valueType" => "integer"
              }
            ]
          })
        end
      end
    end

    context "when privileges is from the subscription (previous override)" do
      it "removes the privileges" do
        sub_entitlement = create(:entitlement, feature:, plan: nil, subscription:)
        create(:entitlement_value, entitlement: sub_entitlement, privilege: privilege2, value: "email")

        result = subject
        result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
        expect(result_data).to eq({
          "code" => "seats",
          "name" => "SEATS",
          "privileges" => [
            {
              "code" => "max",
              "value" => "100",
              "valueType" => "integer"
            }
          ]
        })
      end
    end
  end

  context "when feature is on plan" do
    it "overrides the value" do
      entitlement = create(:entitlement, plan:, feature:)
      create(:entitlement_value, entitlement:, privilege:, value: "2")
      result = subject

      result_data = result["data"]["createOrUpdateSubscriptionEntitlement"]
      expect(result_data).to eq({
        "code" => "seats",
        "name" => "SEATS",
        "privileges" => [
          {
            "code" => "max",
            "value" => "100",
            "valueType" => "integer"
          }
        ]
      })
    end
  end

  context "when feature does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        entitlement: {
          featureCode: "not_existing",
          privileges: [
            {privilegeCode: privilege.code, value: "100"}
          ]
        }
      }
    end

    it "returns not found error" do
      expect_graphql_error(result: subject, message: "not_found")
    end
  end

  context "when privilege does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        entitlement: {
          featureCode: feature.code,
          privileges: [
            {privilegeCode: "not exist", value: "100"}
          ]
        }
      }
    end

    it "returns not found error" do
      expect_graphql_error(result: subject, message: "not_found")
    end
  end

  context "when subscription does not exist" do
    let(:input) do
      {
        subscriptionId: "non-existent-id",
        entitlement: {featureCode: feature.code}
      }
    end

    it "returns not found error" do
      expect_graphql_error(result: subject, message: "not_found")
    end
  end
end
