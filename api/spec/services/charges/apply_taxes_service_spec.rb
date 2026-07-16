# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::ApplyTaxesService do
  subject(:apply_service) { described_class.new(charge:, tax_codes:) }

  let(:plan) { create(:plan) }
  let(:charge) { create(:standard_charge, plan:) }
  let(:tax1) { create(:tax, organization: plan.organization, code: "tax1") }
  let(:tax2) { create(:tax, organization: plan.organization, code: "tax2") }
  let(:tax_codes) { [tax1.code, tax2.code] }

  describe "call" do
    it "applies taxes to the charge" do
      expect { apply_service.call }.to change { charge.applied_taxes.count }.from(0).to(2)
    end

    it "unassigns existing taxes" do
      existing = create(:charge_applied_tax, charge:)
      apply_service.call
      expect(Charge::AppliedTax.find_by(id: existing.id)).to be_nil
    end

    it "returns applied taxes" do
      result = apply_service.call
      expect(result.applied_taxes.count).to eq(2)
    end

    context "when charge is not found" do
      let(:charge) { nil }

      it "returns an error" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("charge_not_found")
      end
    end

    context "when tax is not found" do
      let(:tax_codes) { ["unknown"] }

      it "returns an error" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("tax_not_found")
      end
    end

    context "when applied tax is already present" do
      it "does not create a new applied tax" do
        create(:charge_applied_tax, charge:, tax: tax1)
        expect { apply_service.call }.to change { charge.applied_taxes.count }.from(1).to(2)
      end
    end

    context "when trying to apply twice the same tax" do
      let(:tax_codes) { [tax1.code, tax1.code] }

      it "assigns it only once" do
        expect { apply_service.call }.to change { charge.applied_taxes.count }.from(0).to(1)
      end
    end
  end
end
