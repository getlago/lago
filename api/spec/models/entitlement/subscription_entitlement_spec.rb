# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlement do
  describe "initialization" do
    it "creates an instance with no attributes" do
      entitlement = described_class.new

      expect(entitlement.organization_id).to be_nil
      expect(entitlement.entitlement_feature_id).to be_nil
      expect(entitlement.code).to be_nil
      expect(entitlement.name).to be_nil
      expect(entitlement.description).to be_nil
      expect(entitlement.plan_entitlement_id).to be_nil
      expect(entitlement.sub_entitlement_id).to be_nil
      expect(entitlement.plan_id).to be_nil
      expect(entitlement.subscription_id).to be_nil
      expect(entitlement.ordering_date).to be_nil
      expect(entitlement.privileges).to be_nil
    end
  end

  describe "ActiveModel compliance" do
    it "includes ActiveModel::Attributes" do
      expect(described_class.ancestors).to include(ActiveModel::Model)
      expect(described_class.ancestors).to include(ActiveModel::Attributes)
    end
  end

  describe ".for_subscription" do
    let(:organization) { create(:organization) }
    let(:parent) { create(:plan, organization:) }
    let(:subscription) { create(:subscription, organization:, plan: create(:plan, parent:)) }

    it "returns the result from SubscriptionEntitlementQuery" do
      allow(Entitlement::SubscriptionEntitlementQuery).to receive(:call).with(
        organization: subscription.organization,
        filters: {subscription_id: subscription.id, plan_id: parent.id}
      ).and_return("works")

      result = described_class.for_subscription(subscription)

      expect(result).to eq("works")
    end
  end

  describe "#to_h" do
    it "returns a hash" do
      privilege = Entitlement::SubscriptionEntitlementPrivilege.new(code: "max")
      entitlement = described_class.new(code: "seats", privileges: [privilege])
      hash = entitlement.to_h
      expect(hash).to be_a(HashWithIndifferentAccess)
      expect(hash[:privileges].values).to all be_a(HashWithIndifferentAccess)
      expect(hash[:privileges].keys).to eq ["max"]

      entitlement = described_class.new(code: "seats")
      hash = entitlement.to_h

      expect(hash).to be_a(HashWithIndifferentAccess)
      expect(hash[:privileges]).to eq({})
    end
  end
end
