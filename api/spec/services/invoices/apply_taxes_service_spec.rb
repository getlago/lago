# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ApplyTaxesService do
  subject(:apply_service) { described_class.new(invoice:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      fees_amount_cents:,
      coupons_amount_cents:,
      sub_total_excluding_taxes_amount_cents: fees_amount_cents - coupons_amount_cents
    )
  end
  let(:fees_amount_cents) { 3000 }
  let(:coupons_amount_cents) { 0 }

  let(:tax1) { create(:tax, organization:, rate: 10, code: "tax1") }
  let(:tax2) { create(:tax, organization:, rate: 12, code: "tax2") }

  describe "call" do
    context "with non zero fees amount" do
      before do
        fee1 = create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0)
        create(:fee_applied_tax, tax: tax1, fee: fee1, amount_cents: 100)

        fee2 = create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0)
        create(:fee_applied_tax, tax: tax1, fee: fee2, amount_cents: 200)
        create(:fee_applied_tax, tax: tax2, fee: fee2, amount_cents: 240)
      end

      it "creates applied taxes" do
        result = apply_service.call

        expect(result).to be_success

        applied_taxes = result.applied_taxes.sort_by(&:tax_code)
        expect(applied_taxes.count).to eq(2)

        expect(applied_taxes[0]).to have_attributes(
          invoice:,
          tax: tax1,
          tax_description: tax1.description,
          tax_code: tax1.code,
          tax_name: tax1.name,
          tax_rate: 10,
          amount_currency: invoice.currency,
          amount_cents: 300,
          fees_amount_cents: 3000
        )

        expect(applied_taxes[1]).to have_attributes(
          invoice:,
          tax: tax2,
          tax_description: tax2.description,
          tax_code: tax2.code,
          tax_name: tax2.name,
          tax_rate: 12,
          amount_currency: invoice.currency,
          amount_cents: 240,
          fees_amount_cents: 2000
        )

        expect(invoice).to have_attributes(
          taxes_amount_cents: 540,
          taxes_rate: 18,
          fees_amount_cents: 3000
        )
      end
    end

    context "when invoices fees_amount_cents is zero" do
      let(:fees_amount_cents) { 0 }

      before do
        fee1 = create(:fee, invoice:, amount_cents: 0, precise_coupons_amount_cents: 0)
        create(:fee_applied_tax, tax: tax1, fee: fee1, amount_cents: 0)

        fee2 = create(:fee, invoice:, amount_cents: 0, precise_coupons_amount_cents: 0)
        create(:fee_applied_tax, tax: tax1, fee: fee2, amount_cents: 0)
        create(:fee_applied_tax, tax: tax2, fee: fee2, amount_cents: 0)
      end

      it "creates applied_taxes" do
        result = apply_service.call

        expect(result).to be_success

        applied_taxes = result.applied_taxes.sort_by(&:tax_code)
        expect(applied_taxes.count).to eq(2)

        expect(applied_taxes[0]).to have_attributes(
          invoice:,
          tax: tax1,
          tax_description: tax1.description,
          tax_code: tax1.code,
          tax_name: tax1.name,
          tax_rate: 10,
          amount_currency: invoice.currency,
          amount_cents: 0,
          fees_amount_cents: 0
        )

        expect(applied_taxes[1]).to have_attributes(
          invoice:,
          tax: tax2,
          tax_description: tax2.description,
          tax_code: tax2.code,
          tax_name: tax2.name,
          tax_rate: 12,
          amount_currency: invoice.currency,
          amount_cents: 0,
          fees_amount_cents: 0
        )

        expect(invoice).to have_attributes(
          taxes_amount_cents: 0,
          taxes_rate: 16,
          fees_amount_cents: 0
        )
      end
    end

    context "with coupon applied to invoice" do
      let(:coupons_amount_cents) { 1000 }

      before do
        fee1 = create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 1000.fdiv(3))
        create(:fee_applied_tax, tax: tax1, fee: fee1, amount_cents: ((1000 - 1000.fdiv(3)) * 10).fdiv(100))

        fee2 = create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 1000.fdiv(3) * 2)
        create(:fee_applied_tax, tax: tax1, fee: fee2, amount_cents: (2000 - 1000.fdiv(3) * 2 * 10).fdiv(100))
        create(:fee_applied_tax, tax: tax2, fee: fee2, amount_cents: (2000 - 1000.fdiv(3) * 2 * 12).fdiv(100))
      end

      it "taxes the coupon at pro-rata of each fees" do
        result = apply_service.call

        expect(result).to be_success

        applied_taxes = result.applied_taxes.sort_by(&:tax_code)
        expect(applied_taxes.count).to eq(2)

        expect(applied_taxes[0]).to have_attributes(
          invoice:,
          tax: tax1,
          tax_description: tax1.description,
          tax_code: tax1.code,
          tax_name: tax1.name,
          tax_rate: 10,
          amount_currency: invoice.currency,
          amount_cents: 200,
          fees_amount_cents: 2000
        )

        expect(applied_taxes[1]).to have_attributes(
          invoice:,
          tax: tax2,
          tax_description: tax2.description,
          tax_code: tax2.code,
          tax_name: tax2.name,
          tax_rate: 12,
          amount_currency: invoice.currency,
          amount_cents: 160,
          fees_amount_cents: 1333
        )

        expect(invoice).to have_attributes(
          taxes_amount_cents: 360,
          taxes_rate: 18,
          fees_amount_cents: 3000
        )
      end
    end
  end
end
