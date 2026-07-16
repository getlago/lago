# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Entitlement::SubscriptionEntitlementSerializer do
  subject(:serializer) do
    ::CollectionSerializer.new(
      collection,
      described_class,
      collection_name: "entitlements"
    )
  end

  let(:organization) { create(:organization) }
  let(:collection) { Entitlement::SubscriptionEntitlement.for_subscription(subscription) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege1) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }
  let(:privilege2) { create(:privilege, organization:, feature:, code: "reset", value_type: "string") }
  let(:privilege3) { create(:privilege, organization:, feature:, code: "root?", value_type: "boolean") }

  let(:entitlement) { create(:entitlement, plan:, feature:) }
  let(:entitlement_value1) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 30, created_at: 2.days.ago) }
  let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, value: :email) }

  let(:sub_entitlement) { create(:entitlement, subscription:, plan: nil, feature:) }
  let(:entitlement_value3) { create(:entitlement_value, entitlement: sub_entitlement, privilege: privilege3, value: true, created_at: 3.days.ago) }
  let(:entitlement_value25) { create(:entitlement_value, entitlement: sub_entitlement, privilege: privilege2, value: :slack) }

  let(:feature2) { create(:feature, organization:, code: "storage", name: nil, description: nil) }
  let(:privilege4) { create(:privilege, organization:, feature: feature2, code: "limit", name: "L", value_type: "integer") }
  let(:entitlement2) { create(:entitlement, plan:, feature: feature2, created_at: 12.years.ago) }
  let(:entitlement_value4) { create(:entitlement_value, entitlement: entitlement2, privilege: privilege4, value: 100) }
  let(:entitlement25) { create(:entitlement, plan: nil, subscription:, feature: feature2, created_at: 1.year.ago) }
  let(:entitlement_value45) { create(:entitlement_value, entitlement: entitlement25, privilege: privilege4, value: 999) }

  before do
    entitlement_value1
    entitlement_value2
    entitlement_value25
    entitlement_value3
    entitlement_value4
    entitlement_value45
  end

  describe "#serialize" do
    subject { serializer.serialize }

    it "returns the correct structure" do
      expect(subject).to have_key(:entitlements)
      expect(subject[:entitlements]).to be_an(Array)
      expect(subject[:entitlements].length).to eq(2)
    end

    it "groups entitlements by feature" do
      seats = subject[:entitlements].find { |e| e[:code] == "seats" }.deep_symbolize_keys

      expect(seats).to include({
        code: "seats",
        name: "Feature Name",
        description: "Feature Description"
      })
      expect(seats[:privileges]).to contain_exactly({
        code: "root?",
        name: nil,
        value_type: "boolean",
        config: {},
        value: true,
        plan_value: nil,
        override_value: true
      }, {
        code: "max",
        name: nil,
        value_type: "integer",
        config: {},
        value: 30,
        plan_value: 30,
        override_value: nil
      }, {
        code: "reset",
        name: nil,
        value_type: "string",
        config: {},
        value: "slack",
        plan_value: "email",
        override_value: "slack"
      })
      expect(seats[:overrides]).to eq({
        reset: "slack",
        root?: true
      })

      # Privileges are sorted by EntitlementValue.created_at
      expect(seats[:privileges].map { |p| p[:code] }).to eq([entitlement_value3.privilege.code, entitlement_value1.privilege.code, entitlement_value2.privilege.code])

      storage = subject[:entitlements].find { |e| e[:code] == "storage" }.deep_symbolize_keys

      expect(storage).to include({
        code: "storage",
        name: nil,
        description: nil
      })
      expect(storage[:privileges]).to contain_exactly({
        code: "limit",
        name: "L",
        value_type: "integer",
        config: {},
        value: 999,
        plan_value: 100,
        override_value: 999
      })
      expect(storage[:overrides]).to eq({limit: 999})

      # Features are sorted by Entitlement.created_at
      expect(subject[:entitlements].map { |p| p[:code] }).to eq([feature2.code, feature.code])
    end

    context "when there are no entitlements" do
      let(:collection) { [] }

      it "returns empty array" do
        expect(subject[:entitlements]).to eq([])
      end
    end

    context "when subscription has no overrides" do
      let(:subscription_without_override) { create(:subscription, organization:, plan:) }
      let(:collection) {
        Entitlement::SubscriptionEntitlement.for_subscription(subscription_without_override)
      }

      it "returns the same entitlements as plan" do
        expect(subject[:entitlements].map { it[:overrides] }).to all be_empty
        expect(subject[:entitlements].map { it[:code] }).to eq %w[storage seats]
        expect(subject[:entitlements].map { it[:privileges] }.flatten).to contain_exactly({
          code: "limit",
          name: "L",
          value_type: "integer",
          config: {},
          value: 100,
          plan_value: 100,
          override_value: nil
        }, {
          code: "max",
          name: nil,
          value_type: "integer",
          config: {},
          value: 30,
          plan_value: 30,
          override_value: nil
        }, {
          code: "reset",
          name: nil,
          value_type: "string",
          config: {},
          value: "email",
          plan_value: "email",
          override_value: nil
        })
      end
    end

    context "when feature has no entitlements" do
      let(:other_sub) { create(:subscription, organization:, plan:) }
      let(:collection) {
        Entitlement::SubscriptionEntitlement.for_subscription(other_sub)
      }

      before do
        api_v2 = create(:feature, organization:, code: "api_v2")
        create(:entitlement, organization:, feature: api_v2, plan: nil, subscription: other_sub, created_at: 1.hour.from_now)
      end

      it "returns the same entitlements as plan" do
        expect(subject[:entitlements].map { it[:code] }).to eq %w[storage seats api_v2]
        expect(subject[:entitlements].last[:overrides]).to be_empty
        expect(subject[:entitlements].last[:privileges]).to be_empty
      end
    end
  end
end
