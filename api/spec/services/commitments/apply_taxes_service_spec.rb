# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitments::ApplyTaxesService do
  subject(:apply_service) { described_class.new(commitment:, tax_codes:) }

  let(:commitment) { create(:commitment, plan:) }
  let(:plan) { create(:plan, organization:) }
  let(:organization) { create(:organization) }
  let(:tax1) { create(:tax, organization:, code: "tax1") }
  let(:tax2) { create(:tax, organization:, code: "tax2") }
  let(:tax_codes) { [tax1.code, tax2.code] }

  describe "call" do
    it "applies taxes to the commitment" do
      expect { apply_service.call }.to change { commitment.applied_taxes.count }.from(0).to(2)
    end

    it "returns applied taxes" do
      result = apply_service.call
      expect(result.applied_taxes.count).to eq(2)
    end

    context "when commitment is not found" do
      let(:commitment) { nil }

      it "returns an error" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("commitment_not_found")
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
        create(:commitment_applied_tax, commitment:, tax: tax1)
        expect { apply_service.call }.to change { commitment.applied_taxes.count }.from(1).to(2)
      end
    end

    context "when trying to apply twice the same tax" do
      let(:tax_codes) { [tax1.code, tax1.code] }

      it "assigns it only once" do
        expect { apply_service.call }.to change { commitment.applied_taxes.count }.from(0).to(1)
      end
    end
  end
end
