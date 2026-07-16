# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Entitlement::SubscriptionEntitlementsResolver, :premium do
  subject { execute_query(query:, variables:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, plan:) }
  let(:required_permission) { "subscriptions:view" }
  let(:query) do
    <<~GQL
      query($subscriptionId: ID!) {
        subscriptionEntitlements(subscriptionId: $subscriptionId) {
          collection {
            code
            name
            description
            privileges {
              code
              name
              valueType
              config { selectOptions }
            }
          }
        }
      }
    GQL
  end

  let(:variables) { {subscriptionId: subscription.id} }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:view"

  it do
    expect(described_class).to accept_argument(:subscription_id).of_type("ID!")
  end

  context "when subscription has no features" do
    it "returns an empty list" do
      result = subject
      expect(result["data"]["subscriptionEntitlements"]["collection"]).to be_empty
    end
  end

  context "when subscription has features" do
    it "returns entitlements" do
      feature = create(:feature, organization:, code: "seats")
      privilege_1 = create(:privilege, feature:, code: "max", value_type: "integer")
      privilege_2 = create(:privilege, feature:, code: "root", value_type: "boolean")
      privilege_3 = create(:privilege, feature:, code: "reset", value_type: "select", config: {select_options: %w[yes no]})

      entitlement = create(:entitlement, feature:, plan:)
      create(:entitlement_value, entitlement:, privilege: privilege_1, value: 10)
      create(:entitlement_value, entitlement:, privilege: privilege_2, value: true)
      create(:entitlement_value, entitlement:, privilege: privilege_3, value: "yes")

      sub_entitlement_1 = create(:entitlement, feature:, plan: nil, subscription:)
      create(:entitlement_value, entitlement: sub_entitlement_1, privilege: privilege_1, value: 99)

      feature_2 = create(:feature, organization:, code: "storage")
      privilege_2_1 = create(:privilege, feature: feature_2, code: "limit", value_type: "integer")
      sub_entitlement_2 = create(:entitlement, feature: feature_2, subscription:, plan: nil)
      create(:entitlement_value, entitlement: sub_entitlement_2, privilege: privilege_2_1, value: 1_000)

      feature_3 = create(:feature, organization:)
      create(:entitlement) { create(:entitlement, organization:, feature: feature_3, plan: create(:plan, organization:)) }

      result = subject
      data = result["data"]["subscriptionEntitlements"]["collection"]
      expect(data.count).to eq(2)

      expect(data).to contain_exactly({
        "code" => "seats",
        "name" => "Feature Name",
        "description" => "Feature Description",
        "privileges" => [
          {
            "code" => "max",
            "name" => nil,
            "valueType" => "integer",
            "config" => {
              "selectOptions" => nil
            }
          },
          {
            "code" => "root",
            "name" => nil,
            "valueType" => "boolean",
            "config" => {
              "selectOptions" => nil
            }
          },
          {
            "code" => "reset",
            "name" => nil,
            "valueType" => "select",
            "config" => {
              "selectOptions" => [
                "yes",
                "no"
              ]
            }
          }
        ]
      }, {
        "code" => "storage",
        "name" => "Feature Name",
        "description" => "Feature Description",
        "privileges" => [
          {
            "code" => "limit",
            "name" => nil,
            "valueType" => "integer",
            "config" => {
              "selectOptions" => nil
            }
          }
        ]
      })
    end
  end

  it "does not trigger N+1 queries for privileges", :bullet do
    features = create_list(:feature, 3, organization:)
    features.each do |feature|
      privilege = create(:privilege, feature:)
      entitlement = Entitlement::Entitlement.create(organization:, feature: feature, plan:)
      Entitlement::EntitlementValue.create(organization:, entitlement:, privilege:, value: "val")
    end

    subject
  end
end
