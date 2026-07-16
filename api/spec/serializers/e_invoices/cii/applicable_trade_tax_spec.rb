# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::ApplicableTradeTax do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, tax_category:, tax_rate:, basis_amount:, tax_amount:)
    end
  end

  let(:tax_category) { described_class::S_CATEGORY }
  let(:tax_rate) { 20.00 }
  let(:basis_amount) { 10 }
  let(:tax_amount) { basis_amount * (tax_rate / 100) }

  let(:root) { "//ram:ApplicableTradeTax" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Tax Information 20.00% VAT")
    end

    it "have the tax calculated amount" do
      expect(subject).to contains_xml_node("#{root}/ram:CalculatedAmount").with_value("2.00")
    end

    it "has the tax type code" do
      expect(subject).to contains_xml_node("#{root}/ram:TypeCode").with_value("VAT")
    end

    it "has the tax basis amount" do
      expect(subject).to contains_xml_node("#{root}/ram:BasisAmount").with_value("10.00")
    end

    it "has the category code" do
      expect(subject).to contains_xml_node("#{root}/ram:CategoryCode").with_value(described_class::S_CATEGORY)
    end

    it "has the rate applicable percent" do
      expect(subject).to contains_xml_node("#{root}/ram:RateApplicablePercent").with_value("20.00")
    end

    context "when category code is O" do
      let(:tax_category) { described_class::O_CATEGORY }

      it "has ExemptionReasonCode" do
        expect(subject).to contains_xml_node("#{root}/ram:ExemptionReasonCode").with_value(described_class::O_VAT_EXEMPTION)
      end

      it "does not has rate applicable percent" do
        expect(subject).not_to contains_xml_node("#{root}/ram:RateApplicablePercent")
      end
    end
  end
end
