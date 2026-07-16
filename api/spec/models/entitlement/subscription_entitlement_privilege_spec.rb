# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlementPrivilege do
  describe "initialization" do
    it "creates an instance with no attributes" do
      privilege = described_class.new

      expect(privilege.organization_id).to be_nil
      expect(privilege.entitlement_feature_id).to be_nil
      expect(privilege.code).to be_nil
      expect(privilege.value).to be_nil
      expect(privilege.value_type).to be_nil
      expect(privilege.plan_value).to be_nil
      expect(privilege.subscription_value).to be_nil
      expect(privilege.name).to be_nil
      expect(privilege.config).to be_nil
      expect(privilege.ordering_date).to be_nil
      expect(privilege.plan_entitlement_id).to be_nil
      expect(privilege.sub_entitlement_id).to be_nil
      expect(privilege.plan_entitlement_value_id).to be_nil
      expect(privilege.sub_entitlement_value_id).to be_nil
    end
  end

  describe "ActiveModel compliance" do
    it "includes ActiveModel::Attributes" do
      expect(described_class.ancestors).to include(ActiveModel::Model)
      expect(described_class.ancestors).to include(ActiveModel::Attributes)
    end
  end

  describe "#to_h" do
    it "returns a hash" do
      entitlement = described_class.new(code: "seats", config: {json: true}.to_json)
      hash = entitlement.to_h
      expect(hash).to be_a(HashWithIndifferentAccess)
      expect(hash[:config]).to be_a(HashWithIndifferentAccess)
    end
  end
end
