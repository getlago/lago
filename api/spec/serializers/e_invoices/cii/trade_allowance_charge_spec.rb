# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::TradeAllowanceCharge do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, resource:, indicator:, tax_rate:, amount:) do
      end
    end
  end

  let(:indicator) { described_class::INVOICE_DISCOUNT }
  let(:resource) { create(:invoice) }
  let(:tax_rate) { 19.00 }
  let(:amount) { Money.new(1000) }

  let(:root) { "//ram:SpecifiedTradeAllowanceCharge" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Allowance/Charge - Discount 19.00% portion")
    end

    context "when discount" do
      it "use discount indicator" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeIndicator/udt:Indicator")
          .with_value(false)
      end
    end

    context "when charge" do
      let(:indicator) { described_class::INVOICE_CHARGE }

      it "use charge indicator" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeIndicator/udt:Indicator")
          .with_value(false)
      end
    end

    it "has the ActualAmount" do
      expect(subject).to contains_xml_node("#{root}/ram:ActualAmount")
        .with_value("10.00")
    end

    it "has the Reason" do
      expect(subject).to contains_xml_node("#{root}/ram:Reason")
        .with_value("Discount 19.00% portion")
    end

    context "with CategoryTradeTax" do
      let(:trade_tax_root) { "#{root}/ram:CategoryTradeTax" }

      it "has the TypeCode" do
        expect(subject).to contains_xml_node("#{trade_tax_root}/ram:TypeCode")
          .with_value("VAT")
      end

      context "with tax_category" do
        it "has the S tax category code" do
          expect(subject).to contains_xml_node("#{trade_tax_root}/ram:CategoryCode").with_value("S")
        end

        context "when taxes are zero" do
          let(:tax_rate) { 0.00 }

          it "has the Z category code" do
            expect(subject).to contains_xml_node("#{trade_tax_root}/ram:CategoryCode").with_value("Z")
          end
        end
      end

      it "has the RateApplicablePercent" do
        expect(subject).to contains_xml_node("#{trade_tax_root}/ram:RateApplicablePercent")
          .with_value("19.00")
      end
    end
  end
end
