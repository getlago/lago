# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Invoices::Cii::Builder do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, invoice:)
    end
  end

  let(:invoice) { create(:invoice, invoice_type:, currency: "USD", total_amount_cents: 3000, payment_due_date: "20250316".to_date) }
  let(:invoice_type) { :one_off }
  let(:invoice_fee1) { create(:fee, invoice:, units: 5, amount: 10, precise_unit_amount: 2) }
  let(:invoice_fee2) { create(:fee, invoice:, units: 1, amount: 25, precise_unit_amount: 25) }

  before do
    invoice_fee1
    invoice_fee2
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
              .with_value(invoice.number)
          end
        end

        context "when TypeCode" do
          context "when credit invoice" do
            let(:invoice_type) { :credit }

            it "contains the PREPAID_CREDIT code" do
              expect(subject).to contains_xml_node("#{root}/ram:TypeCode")
                .with_value(described_class::PREPAID_INVOICE)
            end
          end

          context "when self_billed invoice" do
            before { invoice.update(self_billed: true) }

            it "contains the SELF_BILLED_INVOICE code" do
              expect(subject).to contains_xml_node("#{root}/ram:TypeCode")
                .with_value(described_class::SELF_BILLED_INVOICE)
            end
          end

          context "when other invoice types" do
            it "contains the COMMERCIAL_INVOICE code" do
              expect(subject).to contains_xml_node("#{root}/ram:TypeCode")
                .with_value(described_class::COMMERCIAL_INVOICE)
            end
          end
        end

        context "when IssueDateTime" do
          it "contains the info" do
            expect(subject).to contains_xml_node("#{root}/ram:IssueDateTime/udt:DateTimeString")
              .with_value(invoice.issuing_date.strftime(described_class::DATEFORMAT))
              .with_attribute("format", described_class::CCYYMMDD)
          end
        end

        context "when IncludedNote" do
          it "contains the notes" do
            expect(subject.xpath("#{root}/ram:IncludedNote/ram:Content").length).to eq(1)
          end
        end
      end
    end

    context "when SupplyChainTradeTransaction tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//rsm:SupplyChainTradeTransaction")
      end
    end

    context "when IncludedSupplyChainTradeLineItem tags" do
      it "has all fees" do
        expect(
          subject.xpath(
            "//rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem"
          ).length
        ).to eq(invoice.fees.count)
      end

      context "with BilledQuantity" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:BilledQuantity"
          ).with_value(invoice_fee1.units)
        end
      end

      context "with LineTotalAmount" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:LineTotalAmount"
          ).with_value(invoice_fee1.amount)
        end
      end
    end

    context "when ApplicableHeaderTradeAgreement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement")
      end

      it "contains SpecifiedTaxRegistration tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement//ram:SpecifiedTaxRegistration/ram:ID")
          .with_value(invoice.billing_entity.tax_identification_number)
          .with_attribute("schemeID", "VA")
      end

      context "when credit invoice" do
        let(:invoice_type) { :credit }

        it "do not contain SpecifiedTaxRegistration tag" do
          expect(subject).not_to contains_xml_node("//ram:ApplicableHeaderTradeAgreement//ram:SpecifiedTaxRegistration/ram:ID")
        end
      end
    end

    context "when BuyerOrderReferencedDocument tag" do
      it "is absent without a purchase order number" do
        expect(subject).not_to contains_xml_node("//ram:BuyerOrderReferencedDocument")
      end

      context "with a purchase order number" do
        before { invoice.update!(purchase_order_number: "PO-12345") }

        it "contains the purchase order number" do
          expect(subject).to contains_xml_node("//ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID").with_value("PO-12345")
        end
      end
    end

    context "when ApplicableHeaderTradeDelivery tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery")
      end

      context "when one_off invoice" do
        let(:invoice_type) { :one_off }

        it "contains OccurrenceDateTime" do
          expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery//udt:DateTimeString")
            .with_value(invoice.created_at.strftime(described_class::DATEFORMAT))
            .with_attribute("format", described_class::CCYYMMDD)
        end
      end

      context "when credit invoice" do
        let(:invoice_type) { :credit }

        it "contains OccurrenceDateTime" do
          expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery//udt:DateTimeString")
            .with_value(invoice.created_at.strftime(described_class::DATEFORMAT))
            .with_attribute("format", described_class::CCYYMMDD)
        end
      end

      context "when subscription invoice" do
        let(:invoice_type) { :subscription }
        let(:invoice_subscription) { create(:invoice_subscription, :boundaries, invoice:, subscription: subscription) }
        let(:subscription) { create(:subscription, started_at: "2025-03-16".to_date) }

        before { invoice_subscription }

        it "contains OccurrenceDateTime" do
          travel_to(subscription.started_at + 1.month) do
            expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery//udt:DateTimeString")
              .with_value(Time.zone.today.beginning_of_month.strftime(described_class::DATEFORMAT))
              .with_attribute("format", described_class::CCYYMMDD)
          end
        end
      end
    end

    context "when ApplicableHeaderTradeSettlement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement")
      end

      it "contains InvoiceCurrencyCode" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode")
          .with_value(invoice.currency)
      end
    end

    context "when SpecifiedTradeSettlementPaymentMeans tags" do
      before do
        invoice.update(prepaid_credit_amount: 10, credit_notes_amount: 20)
      end

      it "contains the tags" do
        expect(
          subject.xpath(
            "//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans"
          ).length
        ).to eq(3)
      end

      it "has one for STANDARD_PAYMENT" do
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[1]/ram:TypeCode"
        ).with_value(described_class::STANDARD_PAYMENT)
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[1]/ram:Information"
        )
      end

      it "has one for PREPAID_PAYMENT" do
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[2]/ram:TypeCode"
        ).with_value(described_class::PREPAID_PAYMENT)
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[2]/ram:Information"
        )
      end

      it "has one for CREDIT_NOTE_PAYMENT" do
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[3]/ram:TypeCode"
        ).with_value(described_class::CREDIT_NOTE_PAYMENT)
        expect(subject).to contains_xml_node(
          "//ram:SpecifiedTradeSettlementPaymentMeans[3]/ram:Information"
        )
      end
    end

    context "when ApplicableTradeTax tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:ApplicableTradeTax" }

      let(:invoice) { create(:invoice, coupons_amount_cents: 100, invoice_type:) }
      let(:invoice_fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_amount_cents: 1000, taxes_precise_amount_cents: 0) }
      let(:invoice_fee2) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 100, taxes_precise_amount_cents: 4.75) }
      let(:invoice_fee3) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 300, taxes_precise_amount_cents: 14.25) }
      let(:invoice_fee4) { create(:fee, invoice:, taxes_rate: 10.0, precise_amount_cents: 600, taxes_precise_amount_cents: 57) }

      before do
        invoice_fee1
        invoice_fee2
        invoice_fee3
        invoice_fee4
      end

      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/ram:CalculatedAmount").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/ram:BasisAmount").with_value("9.50")
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryCode").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/ram:RateApplicablePercent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/ram:CalculatedAmount").with_value("0.19")
          expect(subject).to contains_xml_node("#{root}[2]/ram:BasisAmount").with_value("3.80")
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/ram:RateApplicablePercent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/ram:CalculatedAmount").with_value("0.57")
          expect(subject).to contains_xml_node("#{root}[3]/ram:BasisAmount").with_value("5.70")
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/ram:RateApplicablePercent").with_value("10.00")
        end
      end
    end

    context "when SpecifiedTradeAllowanceCharge tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:SpecifiedTradeAllowanceCharge" }

      let(:invoice) { create(:invoice, coupons_amount_cents: 100, invoice_type:) }
      let(:invoice_fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_amount_cents: 1000, taxes_precise_amount_cents: 0) }
      let(:invoice_fee2) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 100, taxes_precise_amount_cents: 4.75) }
      let(:invoice_fee3) { create(:fee, invoice:, taxes_rate: 5.0, precise_amount_cents: 300, taxes_precise_amount_cents: 14.25) }
      let(:invoice_fee4) { create(:fee, invoice:, taxes_rate: 10.0, precise_amount_cents: 600, taxes_precise_amount_cents: 57) }

      before do
        invoice_fee1
        invoice_fee2
        invoice_fee3
        invoice_fee4
      end

      it "contains SpecifiedTradeAllowanceCharge tags" do
        expect(subject.xpath(root).length).to eq(3)
      end

      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[1]/ram:ActualAmount").with_value("0.50")
          expect(subject).to contains_xml_node("#{root}[1]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[2]/ram:ActualAmount").with_value("0.20")
          expect(subject).to contains_xml_node("#{root}[2]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/ram:ChargeIndicator/udt:Indicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[3]/ram:ActualAmount").with_value("0.30")
          expect(subject).to contains_xml_node("#{root}[3]/ram:Reason")
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryTradeTax/ram:CategoryCode").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/ram:CategoryTradeTax/ram:RateApplicablePercent").with_value("10.00")
        end
      end

      context "when all fees have zero precise_amount_cents" do
        let(:invoice) { create(:invoice, coupons_amount_cents: 100, invoice_type:) }
        let(:invoice_fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_amount_cents: 0, taxes_precise_amount_cents: 0) }
        let(:invoice_fee2) { nil }
        let(:invoice_fee3) { nil }
        let(:invoice_fee4) { nil }

        it "does not raise an error" do
          expect { subject }.not_to raise_error
        end

        it "does not contain SpecifiedTradeAllowanceCharge tags" do
          expect(subject.xpath(root).length).to eq(0)
        end
      end
    end

    context "when SpecifiedTradePaymentTerms tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms")
      end

      it "contains Description tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms/ram:Description")
      end

      it "contains DueDateDateTime tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradePaymentTerms//udt:DateTimeString")
          .with_value(invoice.payment_due_date.strftime(described_class::DATEFORMAT))
          .with_attribute("format", described_class::CCYYMMDD)
      end
    end

    context "when SpecifiedTradeSettlementHeaderMonetarySummation tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:SpecifiedTradeSettlementHeaderMonetarySummation" }

      let(:invoice) do
        create(:invoice,
          invoice_type:,
          coupons_amount_cents: 100,
          fees_amount: 35,
          sub_total_excluding_taxes_amount: 35,
          taxes_amount: 5,
          sub_total_including_taxes_amount: 40,
          prepaid_credit_amount: 5,
          credit_notes_amount: 5,
          total_amount: 30)
      end

      it "contains the tag" do
        expect(subject).to contains_xml_node(root)
      end

      it "contains LineTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:LineTotalAmount").with_value("35.00")
      end

      it "contains ChargeTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeTotalAmount").with_value("0.00")
      end

      it "contains AllowanceTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:AllowanceTotalAmount").with_value("1.00")
      end

      it "contains TaxBasisTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxBasisTotalAmount").with_value("35.00")
      end

      it "contains TaxTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxTotalAmount").with_value("5.00")
      end

      it "contains GrandTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:GrandTotalAmount").with_value("40.00")
      end

      it "contains DuePayableAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:DuePayableAmount").with_value("30.00")
      end
    end
  end
end
