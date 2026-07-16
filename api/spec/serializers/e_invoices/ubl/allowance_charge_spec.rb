# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::AllowanceCharge do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:, indicator:, tax_rate:, amount:)
    end
  end

  let(:indicator) { described_class::INVOICE_DISCOUNT }
  let(:resource) { invoice }
  let(:invoice) { create(:invoice, currency: "USD") }
  let(:tax_rate) { 19.00 }
  let(:amount) { Money.new(1000) }

  let(:root) { "//cac:AllowanceCharge" }

  before { invoice }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Allowances and Charges - Discount 19.00% portion")
    end

    it "has the ChargeIndicator" do
      expect(subject).to contains_xml_node("#{root}/cbc:ChargeIndicator").with_value(indicator)
    end

    it "has the AllowanceChargeReason" do
      expect(subject).to contains_xml_node("#{root}/cbc:AllowanceChargeReason")
        .with_value("Discount 19.00% portion")
    end

    it "has the Amount" do
      expect(subject).to contains_xml_node("#{root}/cbc:Amount")
        .with_value("10.00")
        .with_attribute("currencyID", "USD")
    end

    context "when TaxCategory" do
      let(:xpath) { "#{root}/cac:TaxCategory" }

      it "has the ID" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:ID").with_value("S")
      end

      it "has the Percent" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:Percent").with_value("19.00")
      end

      context "when TaxScheme" do
        it "has the ID" do
          expect(subject).to contains_xml_node("#{xpath}/cac:TaxScheme/cbc:ID").with_value("VAT")
        end
      end
    end
  end
end
