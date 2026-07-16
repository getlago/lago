# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOns::ApplyTaxesService do
  subject(:apply_service) { described_class.new(add_on:, tax_codes:) }

  let(:organization) { create(:organization) }
  let(:add_on) { create(:add_on, organization:) }
  let(:tax1) { create(:tax, organization:, code: "tax1") }
  let(:tax2) { create(:tax, organization:, code: "tax2") }
  let(:tax_codes) { [tax1.code, tax2.code] }

  describe "call" do
    it "applies taxes to the add_on" do
      expect { apply_service.call }.to change { add_on.applied_taxes.count }.from(0).to(2)
    end

    it "returns applied taxes" do
      result = apply_service.call
      expect(result.applied_taxes.count).to eq(2)
    end

    context "when add_on is not found" do
      let(:add_on) { nil }

      it "returns an error" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("add_on_not_found")
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
        create(:add_on_applied_tax, add_on:, tax: tax1, organization:)
        expect { apply_service.call }.to change { add_on.applied_taxes.count }.from(1).to(2)
      end
    end

    context "when trying to apply twice the same tax" do
      let(:tax_codes) { [tax1.code, tax1.code] }

      it "assigns it only once" do
        expect { apply_service.call }.to change { add_on.applied_taxes.count }.from(0).to(1)
      end
    end
  end
end
