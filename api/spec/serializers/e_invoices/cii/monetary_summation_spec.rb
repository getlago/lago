# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::MonetarySummation do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, resource:, amounts:) do
      end
    end
  end

  let(:resource) { create(:invoice, currency: "USD") }
  let(:amounts) do
    described_class::Amounts.new(
      line_total_amount: Money.new(100000),
      charges_amount: Money.new(1000),
      allowances_amount: Money.new(1000),
      tax_basis_amount: Money.new(99000),
      tax_amount: Money.new(19884),
      grand_total_amount: Money.new(118884),
      prepaid_amount: Money.new(2186),
      due_payable_amount: Money.new(118884)
    )
  end

  let(:root) { "//ram:SpecifiedTradeSettlementHeaderMonetarySummation" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Monetary Summation")
    end

    it "have LineTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:LineTotalAmount")
        .with_value("1000.00")
    end

    it "have ChargeTotalAmount and AllowanceTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:ChargeTotalAmount")
        .with_value("10.00")
      expect(subject).to contains_xml_node("#{root}/ram:AllowanceTotalAmount")
        .with_value("10.00")
    end

    it "have TaxBasisTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:TaxBasisTotalAmount")
        .with_value("990.00")
    end

    it "have TaxTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:TaxTotalAmount")
        .with_value("198.84")
        .with_attribute("currencyID", "USD")
    end

    it "have GrandTotalAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:GrandTotalAmount")
        .with_value("1188.84")
    end

    it "have TotalPrepaidAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:TotalPrepaidAmount")
        .with_value("21.86")
    end

    it "have DuePayableAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:DuePayableAmount")
        .with_value("1188.84")
    end

    context "when resource is credit note" do
      let(:resource) { create(:credit_note, total_amount_currency: "EUR") }

      it "have TaxTotalAmount" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxTotalAmount")
          .with_value("198.84")
          .with_attribute("currencyID", "EUR")
      end
    end

    context "with default amount values" do
      let(:amounts) do
        described_class::Amounts.new(
          line_total_amount: Money.new(100000),
          tax_basis_amount: Money.new(99000),
          tax_amount: Money.new(19884),
          grand_total_amount: Money.new(118884),
          due_payable_amount: Money.new(118884)
        )
      end

      it "have ChargeTotalAmount and AllowanceTotalAmount as zero" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeTotalAmount")
          .with_value("0.00")
        expect(subject).to contains_xml_node("#{root}/ram:AllowanceTotalAmount")
          .with_value("0.00")
      end

      it "does not have TotalPrepaidAmount" do
        expect(subject).not_to contains_xml_node("#{root}/ram:TotalPrepaidAmount")
      end
    end
  end
end
