# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Invoices::Ubl::Builder do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, invoice:)
    end
  end

  let(:invoice) { create(:invoice, invoice_type:, currency: "USD", total_amount_cents: 3000, payment_due_date: "20250316".to_date, taxes_amount_cents: 2500) }
  let(:invoice_type) { :one_off }
  let(:invoice_fee1) { create(:fee, invoice:, units: 5, amount: 10, precise_unit_amount: 2, amount_currency: "EUR") }
  let(:invoice_fee2) { create(:fee, invoice:, units: 1, amount: 25, precise_unit_amount: 25, amount_currency: "EUR") }

  before do
    invoice_fee1
    invoice_fee2
  end

  describe ".serialize" do
    context "when Invoice tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//*[local-name()='Invoice']")
      end

      it "has UBLVersionID tag" do
        expect(subject).to contains_xml_node("//cbc:UBLVersionID").with_value(2.1)
      end

      context "when CustomizationID tag" do
        context "with a non-DE billing entity" do
          before { invoice.billing_entity.update!(country: "FR") }

          it "uses the EN 16931 profile" do
            expect(subject).to contains_xml_node("//cbc:CustomizationID")
              .with_value("urn:cen.eu:en16931:2017")
          end
        end

        context "with a German billing entity" do
          before { invoice.billing_entity.update!(country: "DE") }

          it "uses the XRechnung 3.0 profile" do
            expect(subject).to contains_xml_node("//cbc:CustomizationID")
              .with_value("urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0")
          end
        end
      end

      context "when ProfileID tag" do
        context "with a non-DE billing entity" do
          before { invoice.billing_entity.update!(country: "FR") }

          it "does not insert ProfileID" do
            expect(subject).not_to contains_xml_node("//cbc:ProfileID")
          end
        end

        context "with a German billing entity" do
          before { invoice.billing_entity.update!(country: "DE") }

          it "insert the Peppol BIS Billing 3.0 ProfileID" do
            expect(subject).to contains_xml_node("//cbc:ProfileID")
              .with_value("urn:fdc:peppol.eu:2017:poacc:billing:01:1.0")
          end
        end
      end

      it "has ID tag" do
        expect(subject).to contains_xml_node("//cbc:ID").with_value(invoice.number)
      end

      it "has IssueDate tag" do
        expect(subject).to contains_xml_node("//cbc:IssueDate").with_value(invoice.issuing_date)
      end

      context "when InvoiceTypeCode tag" do
        context "when credit invoice" do
          let(:invoice_type) { :credit }

          it "contains the PREPAID_CREDIT code" do
            expect(subject).to contains_xml_node("//cbc:InvoiceTypeCode")
              .with_value(described_class::PREPAID_INVOICE)
          end
        end

        context "when self_billed invoice" do
          before { invoice.update(self_billed: true) }

          it "contains the SELF_BILLED_INVOICE code" do
            expect(subject).to contains_xml_node("//cbc:InvoiceTypeCode")
              .with_value(described_class::SELF_BILLED_INVOICE)
          end
        end

        context "when other invoice types" do
          it "contains the COMMERCIAL_INVOICE code" do
            expect(subject).to contains_xml_node("//cbc:InvoiceTypeCode")
              .with_value(described_class::COMMERCIAL_INVOICE)
          end
        end
      end

      it "has DocumentCurrencyCode tag" do
        expect(subject).to contains_xml_node("//cbc:DocumentCurrencyCode").with_value(invoice.currency)
      end
    end

    context "when OrderReference tag" do
      it "is absent without a purchase order number" do
        expect(subject).not_to contains_xml_node("//cac:OrderReference")
      end

      context "with a purchase order number" do
        before { invoice.update!(purchase_order_number: "PO-12345") }

        it "contains the purchase order number" do
          expect(subject).to contains_xml_node("//cac:OrderReference/cbc:ID").with_value("PO-12345")
        end
      end
    end

    context "when AccountingSupplierParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:AccountingSupplierParty")
      end

      context "with credit invoice" do
        let(:invoice_type) { :credit }

        it "does not contains PartyTaxScheme tag" do
          expect(subject).not_to contains_xml_node("//cac:AccountingSupplierParty//cac:PartyTaxScheme")
        end
      end

      context "with other invoice types" do
        it "does contains PartyTaxScheme tag" do
          expect(subject).to contains_xml_node("//cac:AccountingSupplierParty//cac:PartyTaxScheme")
        end
      end
    end

    context "when AccountingCustomerParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:AccountingSupplierParty")
      end
    end

    context "when Delivery tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:Delivery")
      end

      context "when invoice types" do
        context "when one_off" do
          let(:invoice_type) { :one_off }

          it "contains the delivery date" do
            expect(subject).to contains_xml_node("//cac:Delivery/cbc:ActualDeliveryDate")
              .with_value(invoice.created_at.strftime(described_class::DATEFORMAT))
          end
        end

        context "when credit" do
          let(:invoice_type) { :credit }

          it "contains the delivery date" do
            expect(subject).to contains_xml_node("//cac:Delivery/cbc:ActualDeliveryDate")
              .with_value(invoice.created_at.strftime(described_class::DATEFORMAT))
          end
        end

        context "when subscription" do
          let(:invoice_type) { :subscription }
          let(:invoice_subscription1) { create(:invoice_subscription, :boundaries, invoice:, subscription: subscription1) }
          let(:invoice_subscription2) { create(:invoice_subscription, :boundaries, invoice:, subscription: subscription2) }
          let(:subscription1) { create(:subscription, started_at: "2025-03-16".to_date) }
          let(:subscription2) { create(:subscription, started_at: "2025-03-26".to_date) }

          before do
            invoice_subscription1
            invoice_subscription2
          end

          it "have the first date of subscription start" do
            travel_to(Time.zone.parse("2025-04-16")) do
              expect(subject).to contains_xml_node("//cac:Delivery/cbc:ActualDeliveryDate")
                .with_value("2025-04-01")
            end
          end
        end
      end
    end

    context "when PaymentMeans tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:PaymentMeans")
      end

      it "has the STANDARD_PAYMENT" do
        expect(subject).to contains_xml_node("//cac:PaymentMeans//cbc:PaymentMeansCode").with_value(1)
      end

      it "emits exactly one PaymentMeans block" do
        expect(subject.xpath("//cac:PaymentMeans").length).to eq(1)
      end

      context "with prepaid credit and credit notes applied" do
        before do
          invoice.update(net_payment_term: 2, prepaid_credit_amount: 10, credit_notes_amount: 20)
        end

        it "still emits exactly one PaymentMeans block" do
          expect(subject.xpath("//cac:PaymentMeans").length).to eq(1)
        end
      end
    end

    context "when PaymentTerms tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:PaymentTerms")
      end

      context "with prepaid and credit notes" do
        before do
          invoice.update(net_payment_term: 2, prepaid_credit_amount: 10, credit_notes_amount: 20)
        end

        it "contains the payment information on note" do
          expect(subject).to contains_xml_node("//cac:PaymentTerms/cbc:Note").with_value(
            "Payment term 2 days, Prepaid credits of USD 10.00 applied, and Credit notes of USD 20.00 applied"
          )
        end
      end
    end

    context "when AllowanceCharge tag" do
      let(:root) { "//cac:AllowanceCharge" }

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

      it "contains AllowanceCharge tags" do
        expect(subject.xpath(root).length).to eq(3)
      end

      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:ChargeIndicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[1]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:Amount").with_value("0.50")
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:ID").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:Percent").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cac:TaxScheme/cbc:ID").with_value("VAT")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/cbc:ChargeIndicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[2]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[2]/cbc:Amount").with_value("0.20")
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:Percent").with_value("5.00")
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cac:TaxScheme/cbc:ID").with_value("VAT")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/cbc:ChargeIndicator").with_value(described_class::INVOICE_DISCOUNT)
          expect(subject).to contains_xml_node("#{root}[3]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[3]/cbc:Amount").with_value("0.30")
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:Percent").with_value("10.00")
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cac:TaxScheme/cbc:ID").with_value("VAT")
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

        it "does not contain AllowanceCharge tags" do
          expect(subject.xpath(root).length).to eq(0)
        end
      end
    end

    context "when TaxTotal tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:TaxTotal")
      end

      it "contains TaxAmount tag" do
        expect(subject).to contains_xml_node("//cac:TaxTotal/cbc:TaxAmount")
          .with_value(Money.new(invoice.taxes_amount))
          .with_attribute("currencyID", invoice.currency)
      end
    end

    context "when TaxSubtotal tag" do
      let(:root) { "//cac:TaxTotal/cac:TaxSubtotal" }

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

      it "contains TaxSubtotal tags" do
        expect(subject.xpath(root).length).to eq(3)
      end

      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxableAmount").with_value("9.50")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxAmount").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:ID").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:Percent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/cbc:TaxableAmount").with_value("3.80")
          expect(subject).to contains_xml_node("#{root}[2]/cbc:TaxAmount").with_value("0.19")
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:Percent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/cbc:TaxableAmount").with_value("5.70")
          expect(subject).to contains_xml_node("#{root}[3]/cbc:TaxAmount").with_value("0.57")
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:Percent").with_value("10.00")
        end
      end
    end

    context "when LegalMonetaryTotal tag" do
      before do
        invoice.update(
          fees_amount: 10,
          sub_total_excluding_taxes_amount: 11,
          sub_total_including_taxes_amount: 12,
          coupons_amount: 6,
          progressive_billing_credit_amount: 7,
          prepaid_credit_amount: 7,
          credit_notes_amount: 7,
          total_amount: 15
        )
      end

      context "when LineExtensionAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:LineExtensionAmount")
            .with_value(invoice.fees_amount)
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when TaxExclusiveAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount")
            .with_value(invoice.sub_total_excluding_taxes_amount)
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when TaxInclusiveAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount")
            .with_value(invoice.sub_total_including_taxes_amount)
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when AllowanceTotalAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:AllowanceTotalAmount")
            .with_value("13.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when ChargeTotalAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:ChargeTotalAmount")
            .with_value("0.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when PrepaidAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:PrepaidAmount")
            .with_value("14.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when PayableAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:PayableAmount")
            .with_value(invoice.total_amount)
            .with_attribute("currencyID", invoice.currency)
        end
      end
    end

    context "when InvoiceLine tags" do
      let(:root) { "//cac:InvoiceLine" }

      it "contains fee tags" do
        expect(subject.xpath(root).length).to eq(2)
      end

      context "with one tag per fee" do
        it "contains the first fee info" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:ID").with_value("1")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:InvoicedQuantity").with_value("5.00").with_attribute("unitCode", described_class::UNIT_CODE)
          expect(subject).to contains_xml_node("#{root}[1]/cbc:LineExtensionAmount").with_value("10.00").with_attribute("currencyID", "EUR")
        end

        it "contains the second fee info" do
          expect(subject).to contains_xml_node("#{root}[2]/cbc:ID").with_value("2")
          expect(subject).to contains_xml_node("#{root}[2]/cbc:InvoicedQuantity").with_value("1.00").with_attribute("unitCode", described_class::UNIT_CODE)
          expect(subject).to contains_xml_node("#{root}[2]/cbc:LineExtensionAmount").with_value("25.00").with_attribute("currencyID", "EUR")
        end
      end
    end
  end
end
