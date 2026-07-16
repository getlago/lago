# frozen_string_literal: true

require "rails_helper"

describe "One-off invoices" do
  let(:organization) { create(:organization, webhook_url: false) }

  describe "tax application" do
    let(:customer) { create(:customer, organization:) }
    let(:addon) { create(:add_on, organization:, amount_cents: 10_000) }

    context "with explicit tax_codes in the payload" do
      let(:tax1) { create(:tax, organization:, code: "vat_20", name: "VAT 20%", rate: 20.0) }
      let(:tax2) { create(:tax, organization:, code: "vat_10", name: "VAT 10%", rate: 10.0) }
      let(:default_tax) { create(:tax, organization:, code: "default_tax", name: "Default", rate: 25.0) }

      before do
        create(:billing_entity_applied_tax, tax: default_tax, billing_entity: customer.billing_entity)
      end

      it "applies the explicit taxes instead of derived taxes" do
        create_one_off_invoice(customer, [addon], taxes: [tax1.code, tax2.code])

        invoice = customer.invoices.sole
        expect(invoice.status).to eq "finalized"

        fee = invoice.fees.sole
        expect(fee.applied_taxes.count).to eq 2
        expect(fee.applied_taxes.map(&:tax_code)).to match_array [tax1.code, tax2.code]

        # 10_000 * 20% + 10_000 * 10% = 3_000
        expect(fee.taxes_amount_cents).to eq 3_000
        expect(invoice.taxes_amount_cents).to eq 3_000
      end
    end

    context "without explicit tax_codes (derived from billing entity taxes)" do
      let(:default_tax) { create(:tax, organization:, code: "default_tax", name: "Default", rate: 15.0) }

      before do
        create(:billing_entity_applied_tax, billing_entity: customer.billing_entity, tax: default_tax)
      end

      it "applies the derived taxes from the billing entity" do
        create_one_off_invoice(customer, [addon])

        invoice = customer.invoices.sole
        expect(invoice.status).to eq "finalized"
        expect(invoice.taxes_amount_cents).to eq 1_500

        fee = invoice.fees.sole
        expect(fee.applied_taxes.sole.tax_code).to eq "default_tax"
        expect(fee.taxes_amount_cents).to eq 1_500
      end
    end

    context "with customer-specific taxes" do
      let(:customer_tax) { create(:tax, organization:, code: "customer_vat", name: "Customer VAT", rate: 8.0) }
      let(:billing_entity_tax) { create(:tax, organization:, code: "be_default", name: "BE Default", rate: 25.0) }

      before do
        create(:billing_entity_applied_tax, billing_entity: customer.billing_entity, tax: billing_entity_tax)
        create(:customer_applied_tax, customer:, tax: customer_tax)
      end

      it "applies customer taxes over billing entity taxes when no explicit tax_codes are provided" do
        create_one_off_invoice(customer, [addon])

        invoice = customer.invoices.sole
        fee = invoice.fees.sole
        expect(fee.applied_taxes.sole.tax_code).to eq "customer_vat"
        expect(fee.taxes_amount_cents).to eq 800
        expect(invoice.taxes_amount_cents).to eq 800
      end

      it "applies explicit tax_codes over customer taxes when provided" do
        explicit_tax = create(:tax, organization:, code: "explicit_vat", name: "Explicit", rate: 5.0)
        create_one_off_invoice(customer, [addon], taxes: [explicit_tax.code])

        invoice = customer.invoices.sole
        fee = invoice.fees.sole
        expect(fee.applied_taxes.sole.tax_code).to eq "explicit_vat"
        expect(fee.taxes_amount_cents).to eq 500
      end
    end

    context "when customer belongs to not default billing entity" do
      let(:secondary_billing_entity) { create(:billing_entity, organization:) }
      let(:tax_1) { create(:tax, organization:, code: "default_tax", name: "Default", rate: 20.0) }
      let(:tax_2) { create(:tax, organization:, code: "secondary_vat", name: "Secondary VAT", rate: 12.0) }
      let(:customer) { create(:customer, organization:, billing_entity: secondary_billing_entity) }
      let(:addon) { create(:add_on, organization:, amount_cents: 10_000) }

      before do
        create(:billing_entity_applied_tax, billing_entity: organization.default_billing_entity, tax: tax_1)
        create(:billing_entity_applied_tax, billing_entity: secondary_billing_entity, tax: tax_2)
      end

      it "applies the customer billing entity's tax rate" do
        create_one_off_invoice(customer, [addon])

        invoice = customer.invoices.sole
        expect(invoice.status).to eq "finalized"

        fee = invoice.fees.sole
        expect(fee.applied_taxes.sole.tax_code).to eq "secondary_vat"
        expect(fee.taxes_amount_cents).to eq 1_200 # 10_000 * 12%
        expect(invoice.taxes_amount_cents).to eq 1_200
      end
    end
  end
end
