# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::Concerns::FixedChargeUnitsOverrideDetectionConcern do
  subject(:host) do
    Class.new do
      include Subscriptions::Concerns::FixedChargeUnitsOverrideDetectionConcern

      public :units_only_fixed_charges_plan_overrides?,
        :units_only_fixed_charge_params?
    end.new
  end

  describe "#units_only_fixed_charges_plan_overrides?" do
    context "when the envelope contains only fixed_charges with valid entries" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be true }
    end

    context "when an entry also carries apply_units_immediately" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5, apply_units_immediately: true}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be true }
    end

    context "with multiple entries that all match" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5}, {id: "fc-2", units: 10}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be true }
    end

    context "with string keys (e.g. ActionController params)" do
      let(:plan_overrides) { {"fixed_charges" => [{"id" => "fc-1", "units" => 5}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be true }
    end

    context "when the envelope is nil" do
      it { expect(host.units_only_fixed_charges_plan_overrides?(nil)).to be false }
    end

    context "when the envelope has other top-level keys alongside fixed_charges" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5}], amount_cents: 1000} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when fixed_charges is missing" do
      let(:plan_overrides) { {amount_cents: 1000} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when fixed_charges is empty" do
      let(:plan_overrides) { {fixed_charges: []} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when an entry is missing id" do
      let(:plan_overrides) { {fixed_charges: [{units: 5}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when an entry is missing units" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1"}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when an entry has unexpected extra keys" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5, invoice_display_name: "x"}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end

    context "when one entry passes and another fails" do
      let(:plan_overrides) { {fixed_charges: [{id: "fc-1", units: 5}, {id: "fc-2", units: 10, amount_cents: 1}]} }

      it { expect(host.units_only_fixed_charges_plan_overrides?(plan_overrides)).to be false }
    end
  end

  describe "#units_only_fixed_charge_params?" do
    context "with only units" do
      it { expect(host.units_only_fixed_charge_params?({units: 5})).to be true }
    end

    context "with units and apply_units_immediately" do
      it { expect(host.units_only_fixed_charge_params?({units: 5, apply_units_immediately: true})).to be true }
    end

    context "with string keys" do
      it { expect(host.units_only_fixed_charge_params?({"units" => 5})).to be true }
    end

    context "when params is nil" do
      it { expect(host.units_only_fixed_charge_params?(nil)).to be false }
    end

    context "when units is missing" do
      it { expect(host.units_only_fixed_charge_params?({apply_units_immediately: true})).to be false }
    end

    context "with unexpected extra keys" do
      it { expect(host.units_only_fixed_charge_params?({units: 5, invoice_display_name: "x"})).to be false }
    end

    context "with an empty hash" do
      it { expect(host.units_only_fixed_charge_params?({})).to be false }
    end
  end
end
