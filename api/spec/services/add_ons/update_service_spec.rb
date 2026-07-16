# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOns::UpdateService do
  subject(:add_ons_service) { described_class.new(add_on:, params: update_args) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:add_on) { create(:add_on, organization:) }
  let(:tax) { create(:tax, organization:) }
  let(:add_on_applied_tax) { create(:add_on_applied_tax, add_on:, tax:) }
  let(:tax2) { create(:tax, organization:) }

  before { add_on_applied_tax }

  describe "call" do
    before { add_on }

    let(:update_args) do
      {
        id: add_on.id,
        name: "new name",
        invoice_display_name: "new invoice name",
        code: "code",
        description: "desc",
        amount_cents: 100,
        amount_currency: "EUR",
        tax_codes:
      }
    end
    let(:tax_codes) { [tax2.code] }

    it "updates the add-on" do
      result = add_ons_service.call
      expect(result).to be_success

      expect(result.add_on.name).to eq("new name")
      expect(result.add_on.invoice_display_name).to eq("new invoice name")
      expect(result.add_on.description).to eq("desc")
      expect(result.add_on.amount_cents).to eq(100)
      expect(result.add_on.amount_currency).to eq("EUR")
      expect(result.add_on.taxes.map { |t| t[:code] }).to contain_exactly(tax2.code)
    end

    context "when tax is not found" do
      let(:tax_codes) { ["unknown"] }

      it "returns an error" do
        result = add_ons_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("tax_not_found")
      end
    end

    context "with validation error" do
      let(:update_args) do
        {
          id: add_on.id,
          name: nil,
          code: "code",
          amount_cents: 100,
          amount_currency: "EUR"
        }
      end

      it "returns an error" do
        result = add_ons_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end

    context "when attached to an applied add on" do
      let(:update_args) do
        {
          id: add_on.id,
          name: "new name",
          description: "new desc",
          code: "new code"
        }
      end

      it "updates all given attributes" do
        create(:applied_add_on, add_on:)
        result = add_ons_service.call

        expect(result.add_on.name).to eq("new name")
        expect(result.add_on.description).to eq("new desc")
        expect(result.add_on.code).to eq("new code")
      end
    end
  end
end
