# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeDisplayHelper do
  subject(:helper) { described_class }

  describe ".format_min_amount" do
    subject { helper.format_min_amount(charge) }

    let(:plan) { create(:plan, amount_currency: "USD") }
    let(:charge) { create(:standard_charge, plan:, min_amount_cents: 500) }

    context "when charge does not have applied pricing unit" do
      it "returns the min amount with the appropriate currency symbol" do
        expect(subject).to eq "$5.00"
      end
    end

    context "when charge has applied pricing unit" do
      let!(:applied_pricing_unit) { create(:applied_pricing_unit, pricing_unitable: charge) }

      it "returns the min amount with the pricing unit's short name" do
        expect(subject).to eq "5.00 #{applied_pricing_unit.pricing_unit.short_name}"
      end
    end
  end
end
