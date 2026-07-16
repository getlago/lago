# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::CreditNotes::Cii::Builder do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, credit_note:)
    end
  end

  let(:credit_note) { create(:credit_note, total_amount_currency: "EUR", credit_amount: 1) }
  let(:credit_note_item1) { create(:credit_note_item, credit_note:, fee:, precise_amount_cents: 1000) }
  let(:credit_note_item2) { create(:credit_note_item, credit_note:, fee: fee2, precise_amount_cents: 2500) }
  let(:fee) { create(:fee, units: 5, amount: 10, precise_unit_amount: 2) }
  let(:fee2) { create(:fee, units: 1, amount: 25, precise_unit_amount: 25) }

  before do
    credit_note_item1
    credit_note_item2

    credit_note.reload
  end

  describe ".serialize" do
    context "when CrossIndustryInvoice tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//rsm:CrossIndustryInvoice")
      end
    end

    context "when ExchangedDocument tag" do
      let(:root) { "//rsm:CrossIndustryInvoice/rsm:ExchangedDocument" }

      it "contains the tag" do
        expect(subject).to contains_xml_node(root)
      end

      context "with credit note info" do
        context "when ID" do
          it "contains the info" do
            expect(subject).to contains_xml_node("#{root}/ram:ID")
              .with_value(credit_note.number)
          end
        end

        context "when TypeCode" do
          it "contains the info" do
            expect(subject).to contains_xml_node("#{root}/ram:TypeCode")
              .with_value(described_class::CREDIT_NOTE)
          end
        end

        context "when IssueDateTime" do
          it "contains the info" do
            expect(subject).to contains_xml_node("#{root}/ram:IssueDateTime/udt:DateTimeString")
              .with_value(credit_note.issuing_date.strftime(described_class::DATEFORMAT))
              .with_attribute("format", described_class::CCYYMMDD)
          end
        end

        context "when IncludedNote" do
          it "contains the notes" do
            expect(subject.xpath("#{root}/ram:IncludedNote/ram:Content").length).to eq(3)
          end
        end
      end
    end

    context "when SupplyChainTradeTransaction tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction")
      end
    end

    context "when IncludedSupplyChainTradeLineItem tags" do
      it "has all fees" do
        expect(
          subject.xpath(
            "//rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem"
          ).length
        ).to eq(credit_note.fees.count)
      end

      context "with negative values" do
        context "with BilledQuantity" do
          it "is negative" do
            expect(subject).to contains_xml_node(
              "//ram:IncludedSupplyChainTradeLineItem[1]//ram:BilledQuantity"
            ).with_value(-fee.units)
          end
        end

        context "with LineTotalAmount" do
          it "is negative" do
            expect(subject).to contains_xml_node(
              "//ram:IncludedSupplyChainTradeLineItem[1]//ram:LineTotalAmount"
            ).with_value(-fee.amount)
          end
        end
      end
    end

    context "when ApplicableHeaderTradeAgreement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement")
      end

      it "contains SpecifiedTaxRegistration tag by default" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement//ram:SpecifiedTaxRegistration/ram:ID")
          .with_value(credit_note.billing_entity.tax_identification_number)
          .with_attribute("schemeID", "VA")
      end
    end

    context "when BuyerOrderReferencedDocument tag" do
      it "is absent without a purchase order number" do
        expect(subject).not_to contains_xml_node("//ram:BuyerOrderReferencedDocument")
      end

      context "with a purchase order number on the invoice" do
        before { credit_note.invoice.update!(purchase_order_number: "PO-12345") }

        it "contains the inherited purchase order number" do
          expect(subject).to contains_xml_node("//ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID").with_value("PO-12345")
        end
      end
    end

    context "when ApplicableHeaderTradeDelivery tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery")
      end

      it "contains OccurrenceDateTime" do
        expect(subject).to contains_xml_node("//ram:ActualDeliverySupplyChainEvent/ram:OccurrenceDateTime/udt:DateTimeString")
          .with_value(credit_note.created_at.strftime(described_class::DATEFORMAT))
          .with_attribute("format", described_class::CCYYMMDD)
      end
    end

    context "when ApplicableHeaderTradeSettlement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement")
      end

      it "contains InvoiceCurrencyCode" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode")
          .with_value(credit_note.currency)
      end
    end

    context "when SpecifiedTradeSettlementPaymentMeans tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans")
      end

      it "contains TypeCode" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans//ram:TypeCode")
          .with_value(described_class::STANDARD_PAYMENT)
      end

      it "contains Information" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans//ram:Information")
          .with_value(I18n.t("invoice.e_invoicing.standard_payment"))
      end
    end

    context "when ApplicableTradeTax tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:ApplicableTradeTax" }

      let(:invoice) { create(:invoice) }
      let(:credit_note) { create(:credit_note, invoice:) }
      let(:credit_note_item0) { create(:credit_note_item, credit_note:, fee: fee0, precise_amount_cents: 500) }
      let(:credit_note_item1) { create(:credit_note_item, credit_note:, fee: fee1, precise_amount_cents: 500) }
      let(:credit_note_item2) { create(:credit_note_item, credit_note:, fee: fee2, precise_amount_cents: 100) }
      let(:credit_note_item3) { create(:credit_note_item, credit_note:, fee: fee3, precise_amount_cents: 300) }
      let(:credit_note_item4) { create(:credit_note_item, credit_note:, fee: fee4, precise_amount_cents: 600) }
      let(:fee0) { create(:fee, invoice:, taxes_rate: 0.0, precise_amount_cents: 500, taxes_precise_amount_cents: 0) }
      let(:fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_amount_cents: 500, taxes_precise_amount_cents: 0) }
      let(:fee2) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 100, taxes_precise_amount_cents: 5) }
      let(:fee3) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 300, taxes_precise_amount_cents: 15) }
      let(:fee4) { create(:fee, invoice:, taxes_rate: 10.0, precise_amount_cents: 600, taxes_precise_amount_cents: 60) }
      let(:credit_note_applied_tax1) { create(:credit_note_applied_tax, credit_note:, tax_rate: 5.0, amount_cents: 20, base_amount_cents: 400) }
      let(:credit_note_applied_tax2) { create(:credit_note_applied_tax, credit_note:, tax_rate: 10.0, amount_cents: 60, base_amount_cents: 600) }

      before do
        credit_note_item0
        credit_note_item1
        credit_note_item2
        credit_note_item3
        credit_note_item4
        credit_note_applied_tax1
        credit_note_applied_tax2
      end

      it "contains ApplicableTradeTax tags" do
        expect(subject.xpath(root).length).to eq(3)
      end

      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/ram:CalculatedAmount").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/ram:BasisAmount").with_value("-10.00")
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryCode").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/ram:RateApplicablePercent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/ram:CalculatedAmount").with_value("-0.20")
          expect(subject).to contains_xml_node("#{root}[2]/ram:BasisAmount").with_value("-4.00")
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/ram:RateApplicablePercent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/ram:CalculatedAmount").with_value("-0.60")
          expect(subject).to contains_xml_node("#{root}[3]/ram:BasisAmount").with_value("-6.00")
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/ram:RateApplicablePercent").with_value("10.00")
        end
      end
    end

    context "when SpecifiedTradeAllowanceCharge tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:SpecifiedTradeAllowanceCharge" }

      let(:invoice) { create(:invoice, coupons_amount_cents: 100) }
      let(:credit_note) { create(:credit_note, invoice:, precise_coupons_adjustment_amount_cents: 100) }
      let(:invoice_fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_coupons_amount_cents: 100, precise_amount_cents: 2000, taxes_precise_amount_cents: 0) }
      let(:invoice_fee2) { create(:fee, invoice:, taxes_rate: 5.0, precise_coupons_amount_cents: 10, precise_amount_cents: 100, taxes_precise_amount_cents: 4.75) }
      let(:invoice_fee3) { create(:fee, invoice:, taxes_rate: 5.0, precise_coupons_amount_cents: 10, precise_amount_cents: 300, taxes_precise_amount_cents: 14.25) }
      let(:invoice_fee4) { create(:fee, invoice:, taxes_rate: 10.0, precise_coupons_amount_cents: 30, precise_amount_cents: 600, taxes_precise_amount_cents: 57) }
      let(:credit_note_item1) { create(:credit_note_item, credit_note:, fee: invoice_fee1, precise_amount_cents: 1000) }
      let(:credit_note_item2) { create(:credit_note_item, credit_note:, fee: invoice_fee2, precise_amount_cents: 100) }
      let(:credit_note_item3) { create(:credit_note_item, credit_note:, fee: invoice_fee3, precise_amount_cents: 300) }
      let(:credit_note_item4) { create(:credit_note_item, credit_note:, fee: invoice_fee4, precise_amount_cents: 600) }

      before do
        credit_note_item1
        credit_note_item2
        credit_note_item3
        credit_note_item4
      end

      it "contains SpecifiedTradeAllowanceCharge tags" do
        expect(subject.xpath(root).length).to eq(3)
      end

      # For credit_note, allowances are turned into charges
      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[1]/ram:ActualAmount").with_value("0.50")
          expect(subject).to contains_xml_node("#{root}[1]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[2]/ram:ActualAmount").with_value("0.20")
          expect(subject).to contains_xml_node("#{root}[2]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[3]/ram:ActualAmount").with_value("0.30")
          expect(subject).to contains_xml_node("#{root}[3]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("10.00")
        end
      end
    end

    context "when SpecifiedTradePaymentTerms tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms")
      end

      it "contains Description tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms/ram:Description")
          .with_value("Credit note - immediate settlement")
      end

      it "contains DueDateDateTime tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms//udt:DateTimeString")
          .with_value(credit_note.created_at.strftime(described_class::DATEFORMAT))
          .with_attribute("format", described_class::CCYYMMDD)
      end
    end

    context "when SpecifiedTradeSettlementHeaderMonetarySummation tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:SpecifiedTradeSettlementHeaderMonetarySummation" }

      let(:invoice) { create(:invoice, coupons_amount_cents: 100) }
      let(:credit_note) { create(:credit_note, invoice:, precise_coupons_adjustment_amount_cents: 100, taxes_amount: 10, total_amount: 20, credit_amount: 10) }

      it "contains the tag" do
        expect(subject).to contains_xml_node(root)
      end

      it "contains LineTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:LineTotalAmount").with_value("-35.00")
      end

      it "contains ChargeTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeTotalAmount").with_value("1.00")
      end

      it "contains AllowanceTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:AllowanceTotalAmount").with_value("0.00")
      end

      it "contains TaxBasisTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxBasisTotalAmount").with_value("-34.00")
      end

      it "contains TaxTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxTotalAmount").with_value("-10.00")
      end

      it "contains GrandTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:GrandTotalAmount").with_value("-20.00")
      end

      it "contains DuePayableAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:DuePayableAmount").with_value("-10.00")
      end
    end
  end
end
