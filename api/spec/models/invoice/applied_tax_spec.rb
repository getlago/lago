# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice::AppliedTax do
  subject(:applied_tax) { create(:invoice_applied_tax) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:organization) }

  describe "#applied_on_whole_invoice?" do
    subject(:applicable_on_whole_invoice) { applied_tax.applied_on_whole_invoice? }

    context "when applied tax represents special rule" do
      let(:applied_tax) { create(:invoice_applied_tax, tax_code: Invoice::AppliedTax::TAX_CODES_APPLICABLE_ON_WHOLE_INVOICE.sample) }

      it "is applicable on whole invoice" do
        expect(subject).to be(true)
      end
    end

    context "when normal applied tax" do
      it "is not applicable on whole invoice" do
        expect(subject).to be(false)
      end
    end
  end

  describe "#taxable_amount_cents" do
    before do
      applied_tax.fees_amount_cents = 150
    end

    context "when taxable_base_amount_cents is zero" do
      it "returns fees_amount_cents" do
        applied_tax.taxable_base_amount_cents = 0

        expect(applied_tax.taxable_amount_cents).to eq(150)
      end
    end

    context "when taxable_base_amount_cents is NOT zero" do
      it "returns taxable_base_amount_cents" do
        applied_tax.taxable_base_amount_cents = 100

        expect(applied_tax.taxable_amount_cents).to eq(100)
      end
    end
  end
end
