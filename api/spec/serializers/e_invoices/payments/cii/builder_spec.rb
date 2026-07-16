# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Payments::Cii::Builder do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, payment:)
    end
  end

  let(:organization) { create(:organization, premium_integrations: %w[issue_receipts]) }
  let(:billing_entity) { create(:billing_entity, tax_identification_number: "MAR1234BR") }
  let(:customer) { create(:customer, billing_entity:) }
  let(:invoice) { create(:invoice, total_amount_cents: 1000, number: "INV-24680-OIC-E") }
  let(:payment) do
    create(:payment,
      customer:,
      payment_type:,
      payable: invoice,
      currency: "BRL",
      amount_cents: 1000,
      reference:,
      provider_payment_method_data: {last4: "4321"})
  end
  let(:payment_type) { "manual" }
  let(:reference) { "its a payment" }
  let(:payment_receipt) { create(:payment_receipt, payment:, organization:) }

  before do
    payment
    payment_receipt
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
              .with_value(payment_receipt.number)
          end
        end

        context "when TypeCode" do
          it "contains the PAYMENT_RECEIPT code" do
            expect(subject).to contains_xml_node("#{root}/ram:TypeCode")
              .with_value(described_class::PAYMENT_RECEIPT)
          end
        end

        context "when IssueDateTime" do
          it "contains the info" do
            expect(subject).to contains_xml_node("#{root}/ram:IssueDateTime/udt:DateTimeString")
              .with_value(payment.created_at.strftime(described_class::DATEFORMAT))
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
      it "has a single item" do
        expect(
          subject.xpath(
            "//rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem"
          ).length
        ).to eq(1)
      end

      context "with Product Name" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:Name"
          ).with_value("Payment Received")
        end
      end

      context "with ChargeAmount" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:ChargeAmount"
          ).with_value(payment.amount)
        end
      end

      context "with BilledQuantity" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:BilledQuantity"
          ).with_value(1)
        end
      end

      context "with ApplicableTradeTax" do
        it "contains the CategoryCode" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:ApplicableTradeTax//ram:CategoryCode"
          ).with_value(described_class::Z_CATEGORY)
        end

        it "contains the RateApplicablePercent" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:ApplicableTradeTax//ram:RateApplicablePercent"
          ).with_value("0.0")
        end
      end

      context "with LineTotalAmount" do
        it "contains the info" do
          expect(subject).to contains_xml_node(
            "//ram:IncludedSupplyChainTradeLineItem[1]//ram:LineTotalAmount"
          ).with_value(payment.amount)
        end
      end
    end

    context "when ApplicableHeaderTradeAgreement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement")
      end

      it "contains SpecifiedTaxRegistration tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeAgreement//ram:SpecifiedTaxRegistration/ram:ID")
          .with_value(billing_entity.tax_identification_number)
          .with_attribute("schemeID", "VA")
      end
    end

    context "when ApplicableHeaderTradeDelivery tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery")
      end

      it "contains OccurrenceDateTime" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeDelivery//udt:DateTimeString")
          .with_value(payment.created_at.strftime(described_class::DATEFORMAT))
          .with_attribute("format", described_class::CCYYMMDD)
      end
    end

    context "when ApplicableHeaderTradeSettlement tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement")
      end

      it "contains InvoiceCurrencyCode" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode")
          .with_value(payment.currency)
      end
    end

    context "when SpecifiedTradeSettlementPaymentMeans tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans")
      end

      it "contains Information" do
        expect(subject).to contains_xml_node("//ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode")
          .with_value("BRL")
      end

      context "when payment is manual" do
        let(:payment_type) { "manual" }

        it "contains TypeCode" do
          expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode")
            .with_value(described_class::STANDARD_PAYMENT)
        end

        it "does not contains card attributes" do
          expect(subject).not_to contains_xml_node("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeSettlementFinancialCard")
        end
      end

      context "when payment is using provider" do
        let(:payment_type) { "provider" }
        let(:reference) { nil }

        it "contains TypeCode" do
          expect(subject).to contains_xml_node("//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode")
            .with_value(described_class::CREDIT_CARD_PAYMENT)
        end

        context "when ApplicableTradeSettlementFinancialCard tag" do
          it "contains ID" do
            expect(subject).to contains_xml_node("//ram:ApplicableTradeSettlementFinancialCard/ram:ID")
              .with_value(payment.card_last_digits)
          end
        end
      end
    end

    context "when ApplicableTradeTax tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:ApplicableTradeTax" }

      context "with a single tag" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/ram:CalculatedAmount").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/ram:BasisAmount").with_value("10.00")
          expect(subject).to contains_xml_node("#{root}[1]/ram:CategoryCode").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/ram:RateApplicablePercent").with_value("0.00")
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
          .with_value(payment.created_at.strftime(described_class::DATEFORMAT))
          .with_attribute("format", described_class::CCYYMMDD)
      end
    end

    context "when SpecifiedTradeSettlementHeaderMonetarySummation tag" do
      let(:root) { "//ram:ApplicableHeaderTradeSettlement//ram:SpecifiedTradeSettlementHeaderMonetarySummation" }

      it "contains the tag" do
        expect(subject).to contains_xml_node(root)
      end

      it "contains LineTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:LineTotalAmount").with_value("10.00")
      end

      it "contains ChargeTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:ChargeTotalAmount").with_value("0.00")
      end

      it "contains AllowanceTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:AllowanceTotalAmount").with_value("0.00")
      end

      it "contains TaxBasisTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxBasisTotalAmount").with_value("10.00")
      end

      it "contains TaxTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:TaxTotalAmount").with_value("0.00")
      end

      it "contains GrandTotalAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:GrandTotalAmount").with_value("10.00")
      end

      it "contains DuePayableAmount tag" do
        expect(subject).to contains_xml_node("#{root}/ram:DuePayableAmount").with_value("0.00")
      end
    end

    context "when InvoiceReferencedDocument tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//ram:InvoiceReferencedDocument")
      end

      it "contains the IssuerAssignedID" do
        expect(subject).to contains_xml_node("//ram:IssuerAssignedID").with_value(invoice.number)
      end
    end
  end
end
