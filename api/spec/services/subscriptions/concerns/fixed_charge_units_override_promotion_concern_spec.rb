# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::Concerns::FixedChargeUnitsOverridePromotionConcern do
  subject(:host) do
    Class.new do
      include Subscriptions::Concerns::FixedChargeUnitsOverridePromotionConcern

      public :promote_units_overrides_to_fixed_charges_params

      attr_accessor :subscription
    end.new
  end

  describe "#promote_units_overrides_to_fixed_charges_params" do
    let(:organization) { create(:organization) }
    let(:plan) { create(:plan, organization:) }
    let(:fc1) { create(:fixed_charge, plan:, organization:, units: 5) }
    let(:fc2) { create(:fixed_charge, plan:, organization:, units: 10) }
    let(:subscription) { create(:subscription, plan:) }

    before { host.subscription = subscription }

    context "when the subscription has no override rows" do
      it "returns the existing params unchanged" do
        existing = [{id: fc1.id, units: 7}]
        expect(host.promote_units_overrides_to_fixed_charges_params(existing)).to eq(existing)
      end

      it "does not touch the database" do
        expect(::Subscription::FixedChargeUnitsOverride.count).to eq(0)
        host.promote_units_overrides_to_fixed_charges_params([])
        expect(::Subscription::FixedChargeUnitsOverride.count).to eq(0)
      end
    end

    context "when override rows exist but no existing params are provided" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: fc1, organization:, units: 11)
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: fc2, organization:, units: 22)
      end

      it "synthesises one entry per override row with the captured units" do
        result = host.promote_units_overrides_to_fixed_charges_params

        expect(result).to contain_exactly(
          {id: fc1.id, units: 11},
          {id: fc2.id, units: 22}
        )
      end

      it "discards the override rows" do
        host.promote_units_overrides_to_fixed_charges_params

        expect(::Subscription::FixedChargeUnitsOverride.kept.where(subscription:)).to be_empty
        expect(::Subscription::FixedChargeUnitsOverride.unscoped.where(subscription:).discarded).to exist
      end
    end

    context "when caller params already include an entry for an overridden fixed_charge" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: fc1, organization:, units: 11)
      end

      it "keeps the caller's entry and discards the override row" do
        result = host.promote_units_overrides_to_fixed_charges_params([{id: fc1.id, units: 99}])

        expect(result).to contain_exactly({id: fc1.id, units: 99})
        expect(::Subscription::FixedChargeUnitsOverride.kept.where(subscription:)).to be_empty
      end
    end

    context "when caller params reference different fixed_charges than the overrides" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: fc1, organization:, units: 11)
      end

      it "preserves caller entries and adds synthetic entries for the overrides" do
        result = host.promote_units_overrides_to_fixed_charges_params([{id: fc2.id, units: 50}])

        expect(result).to contain_exactly(
          {id: fc2.id, units: 50},
          {id: fc1.id, units: 11}
        )
      end
    end

    context "with string-keyed existing params" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: fc1, organization:, units: 11)
      end

      it "normalises string keys and keeps the caller's entry" do
        result = host.promote_units_overrides_to_fixed_charges_params([{"id" => fc1.id, "units" => 99}])

        # Caller entry wins (we don't mutate it). Returned value preserves its original key style.
        expect(result.map { |e| e[:id] || e["id"] }).to contain_exactly(fc1.id)
      end
    end
  end
end
