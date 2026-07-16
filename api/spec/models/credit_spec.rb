# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credit do
  subject(:credit) { create(:credit) }

  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
    it { is_expected.to belong_to(:applied_coupon).optional }
    it { is_expected.to belong_to(:credit_note).optional }
    it { is_expected.to belong_to(:progressive_billing_invoice).optional }
    it { is_expected.to belong_to(:organization) }
  end

  describe "scopes" do
    let!(:active_invoice) { create(:invoice, status: :finalized) }
    let!(:voided_invoice) { create(:invoice, status: :voided) }
    let(:closed_invoice) { create(:invoice, status: :closed) }
    let!(:active_credit) { create(:credit, invoice: active_invoice) }
    let!(:voided_credit) { create(:credit, invoice: voided_invoice) }

    before do
      create(:credit, invoice: closed_invoice)
    end

    describe ".active" do
      it "returns only credits with non-voided and non-closed invoices" do
        expect(described_class.active).to match_array([active_credit])
      end
    end

    describe ".voided" do
      it "returns only credits with voided invoices" do
        expect(described_class.voided).to match_array([voided_credit])
      end
    end
  end

  describe "invoice item" do
    context "when credit is a coupon" do
      subject(:credit) { create(:credit, applied_coupon:) }

      let(:applied_coupon) { create(:applied_coupon, coupon:) }
      let(:coupon) do
        create(
          :coupon,
          code: "coupon_code",
          name: "Coupon name",
          description: "Coupon desc"
        )
      end

      it "returns coupon details" do
        expect(credit.item_id).to eq(coupon.id)
        expect(credit.item_type).to eq("coupon")
        expect(credit.item_code).to eq("coupon_code")
        expect(credit.item_name).to eq("Coupon name")
        expect(credit.item_description).to eq("Coupon desc")
      end

      context "when coupon is deleted" do
        let(:coupon) do
          create(
            :coupon,
            :deleted,
            code: "coupon_code",
            name: "Coupon name",
            description: "Coupon desc",
            amount_cents: 200,
            amount_currency: "EUR"
          )
        end

        it "returns coupon details" do
          expect(credit.item_id).to eq(coupon.id)
          expect(credit.item_type).to eq("coupon")
          expect(credit.item_code).to eq("coupon_code")
          expect(credit.item_name).to eq("Coupon name")
          expect(credit.item_description).to eq("Coupon desc")
          expect(credit.invoice_coupon_display_name).to eq("Coupon name (€2.00)")
        end
      end
    end

    context "when credit is a credit note" do
      subject(:credit) { create(:credit_note_credit) }

      let(:credit_note) do
        c = credit.credit_note
        c.update! description: "Credit note description"
        c
      end

      it "returns credit note details" do
        expect(credit.item_id).to eq(credit_note.id)
        expect(credit.item_type).to eq("credit_note")
        expect(credit.item_code).to eq(credit_note.number)
        expect(credit.item_name).to eq(credit_note.invoice.number)
        expect(credit.item_description).to eq("Credit note description")
      end
    end

    context "when credit is a progressive billing invoice" do
      subject(:credit) { create(:progressive_billing_invoice_credit, progressive_billing_invoice:) }

      let(:progressive_billing_invoice) { create(:invoice, invoice_type: :progressive_billing) }

      it "returns invoice details" do
        expect(credit.item_id).to eq(progressive_billing_invoice.id)
        expect(credit.item_type).to eq("invoice")
        expect(credit.item_code).to eq(progressive_billing_invoice.number)
        expect(credit.item_name).to eq(progressive_billing_invoice.number)
        expect(credit.item_description).to be_nil
      end
    end
  end
end
