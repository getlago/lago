# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::ApplyTaxesService do
  subject(:apply_service) { described_class.new(customer:, tax_codes:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax1) { create(:tax, organization:, code: "tax1") }
  let(:tax2) { create(:tax, organization:, code: "tax2") }
  let(:tax_codes) { [tax1.code, tax2.code] }

  describe "call" do
    it "applies taxes to the customer" do
      expect { apply_service.call }.to change { customer.applied_taxes.count }.from(0).to(2)
    end

    it "marks invoices as ready to be refreshed" do
      invoice = create(:invoice, :draft, customer:)

      expect { apply_service.call }.to change { invoice.reload.ready_to_be_refreshed }.to(true)
    end

    it "returns applied taxes" do
      result = apply_service.call
      expect(result.applied_taxes.count).to eq(2)
    end

    context "when customer is not found" do
      let(:customer) { nil }

      it "returns an error" do
        result = apply_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("customer_not_found")
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
        create(:customer_applied_tax, customer:, tax: tax1)
        expect { apply_service.call }.to change { customer.applied_taxes.count }.from(1).to(2)
      end
    end

    context "when trying to apply twice the same tax" do
      let(:tax_codes) { [tax1.code, tax1.code] }

      it "assigns it only once" do
        expect { apply_service.call }.to change { customer.applied_taxes.count }.from(0).to(1)
      end
    end
  end
end
