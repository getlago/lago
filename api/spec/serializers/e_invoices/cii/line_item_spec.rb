# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::LineItem do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, resource:, data:)
    end
  end

  let(:resource) { create(:invoice) }
  let(:data) do
    described_class::Data.new(
      line_id:,
      name: fee.item_name,
      description: fee.invoice_name,
      charge_amount: fee.precise_unit_amount,
      billed_quantity: fee.units,
      category_code: described_class::S_CATEGORY,
      rate_percent:,
      line_total_amount: fee.amount
    )
  end
  let(:fee) { create(:fee, precise_unit_amount: 0.059, taxes_rate:, fee_type:) }
  let(:taxes_rate) { 20.00 }
  let(:rate_percent) { taxes_rate }
  let(:fee_type) { :subscription }
  let(:line_id) { 1 }

  let(:root) { "//ram:IncludedSupplyChainTradeLineItem" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Line Item #{line_id}: #{fee.invoice_name}")
    end

    it "have the line id" do
      expect(subject).to contains_xml_node("#{root}/ram:AssociatedDocumentLineDocument/ram:LineID")
        .with_value(line_id)
    end

    it "have the item name" do
      expect(subject).to contains_xml_node("#{root}/ram:SpecifiedTradeProduct/ram:Name").with_value(fee.item_name)
    end

    context "when Description tag" do
      it "uses description data field" do
        expect(subject).to contains_xml_node("#{root}/ram:SpecifiedTradeProduct/ram:Description").with_value(fee.invoice_name)
      end
    end

    it "have the item unit amount" do
      expect(subject).to contains_xml_node(
        "#{root}/ram:SpecifiedLineTradeAgreement/ram:NetPriceProductTradePrice/ram:ChargeAmount"
      ).with_value("0.059")
    end

    context "with BilledQuantity" do
      let(:xpath) { "#{root}/ram:SpecifiedLineTradeDelivery/ram:BilledQuantity" }

      it "have the item units" do
        expect(subject).to contains_xml_node(xpath)
          .with_value(fee.units)
          .with_attribute("unitCode", "C62")
      end
    end

    context "with CategoryCode" do
      let(:xpath) { "#{root}/ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:CategoryCode" }

      context "when taxes are not zero" do
        it "has the S category code" do
          expect(subject).to contains_xml_node(xpath).with_value("S")
        end
      end
    end

    context "when RateApplicablePercent" do
      it "have the item taxes rate" do
        expect(subject).to contains_xml_node(
          "#{root}/ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent"
        ).with_value(fee.taxes_rate)
      end

      context "when rate_percent is not available" do
        let(:rate_percent) { nil }

        it "doesnt have the tag" do
          expect(subject).not_to contains_xml_node(
            "#{root}/ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent"
          )
        end
      end
    end

    it "have the item total amount" do
      expect(subject).to contains_xml_node(
        "#{root}/ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount"
      ).with_value(fee.amount)
    end
  end
end
