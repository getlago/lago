# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::MonetaryTotal do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:, amounts:) do
      end
    end
  end

  let(:resource) { invoice }
  let(:amounts) do
    described_class::Amounts.new(
      line_extension_amount: 1000,
      tax_exclusive_amount: 990,
      tax_inclusive_amount: 1188.84,
      allowance_total_amount: 10,
      charge_total_amount: 0,
      prepaid_amount: 21.86,
      payable_amount: 1188.84
    )
  end
  let(:invoice) do
    create(:invoice, currency: "USD")
  end

  let(:root) { "//cac:LegalMonetaryTotal" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Legal Monetary Total")
    end

    it "have LineExtensionAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:LineExtensionAmount")
        .with_value("1000.00")
        .with_attribute("currencyID", "USD")
    end

    it "have ChargeTotalAmount and AllowanceTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:ChargeTotalAmount")
        .with_value("0.00")
        .with_attribute("currencyID", "USD")
      expect(subject).to contains_xml_node("#{root}/cbc:AllowanceTotalAmount")
        .with_value("10.00")
        .with_attribute("currencyID", "USD")
    end

    it "have TaxExclusiveAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:TaxExclusiveAmount")
        .with_value("990.00")
        .with_attribute("currencyID", "USD")
    end

    it "have TaxInclusiveAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:TaxInclusiveAmount")
        .with_value("1188.84")
        .with_attribute("currencyID", "USD")
    end

    it "have PrepaidAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:PrepaidAmount")
        .with_value("21.86")
        .with_attribute("currencyID", "USD")
    end

    it "have PayableAmount" do
      expect(subject).to contains_xml_node("#{root}/cbc:PayableAmount")
        .with_value("1188.84")
        .with_attribute("currencyID", "USD")
    end
  end
end
