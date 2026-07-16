# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::FixedChargePresenter do
  subject(:presenter) { described_class.new(fixed_charge, subscription, effective_units:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, organization:, units: 10) }
  let(:subscription) { create(:subscription, plan:, customer:) }

  describe "#units" do
    context "when effective_units is nil (no override)" do
      let(:effective_units) { nil }

      it "returns the plan-level units from the wrapped FixedCharge" do
        expect(presenter.units).to eq(fixed_charge.units)
      end
    end

    context "when effective_units is provided" do
      let(:effective_units) { 42 }

      it "returns the pre-resolved units" do
        expect(presenter.units).to eq(42)
      end
    end
  end

  describe "delegation" do
    let(:effective_units) { nil }

    it "delegates other reads to the wrapped FixedCharge" do
      expect(presenter.id).to eq(fixed_charge.id)
      expect(presenter.code).to eq(fixed_charge.code)
      expect(presenter.charge_model).to eq(fixed_charge.charge_model)
      expect(presenter.pay_in_advance).to eq(fixed_charge.pay_in_advance)
      expect(presenter.add_on_id).to eq(fixed_charge.add_on_id)
    end
  end
end
