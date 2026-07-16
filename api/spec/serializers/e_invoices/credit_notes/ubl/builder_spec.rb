# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::CreditNotes::Ubl::Builder do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, credit_note:)
    end
  end

  let(:credit_note) { create(:credit_note, invoice:, total_amount_currency: "EUR", credit_amount: 1) }
  let(:invoice) { create(:invoice, number: "LAGO-TEST-123") }

  before do
    credit_note.reload
  end

  describe ".serialize" do
    context "when CreditNote tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//*[local-name()='CreditNote']")
      end

      it "contains UBLVersionID tag" do
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

          it "inserts the Peppol BIS Billing 3.0 ProfileID" do
            expect(subject).to contains_xml_node("//cbc:ProfileID")
              .with_value("urn:fdc:peppol.eu:2017:poacc:billing:01:1.0")
          end
        end
      end

      it "contains header tags" do
        expect(subject).to contains_xml_node("//cbc:ID").with_value(credit_note.number)
        expect(subject).to contains_xml_node("//cbc:IssueDate").with_value(credit_note.issuing_date)
        expect(subject).to contains_xml_node("//cbc:CreditNoteTypeCode").with_value(described_class::CREDIT_NOTE)
        expect(subject).to contains_xml_node("//cbc:DocumentCurrencyCode").with_value(credit_note.currency)
      end

      context "when Note tags" do
        let(:path) { "//*[local-name()='CreditNote']/cbc:Note" }

        it "contains multiple notes" do
          expect(subject.xpath(path).length).to eq(3)
        end

        context "with messages" do
          it "contains credit note id" do
            expect(subject).to contains_xml_node("#{path}[1]").with_value("Credit Note ID: #{credit_note.id}")
          end

          it "contains original invoice id" do
            expect(subject).to contains_xml_node("#{path}[2]").with_value("Original Invoice: #{credit_note.invoice.number}")
          end

          it "contains reason" do
            expect(subject).to contains_xml_node("#{path}[3]").with_value("Reason: #{credit_note.reason}")
          end
        end
      end
    end

    context "when OrderReference tag" do
      it "is absent without a purchase order number" do
        expect(subject).not_to contains_xml_node("//cac:OrderReference")
      end

      context "with a purchase order number on the invoice" do
        before { invoice.update!(purchase_order_number: "PO-12345") }

        it "contains the inherited purchase order number" do
          expect(subject).to contains_xml_node("//cac:OrderReference/cbc:ID").with_value("PO-12345")
        end
      end
    end

    context "when BillingReference tag" do
      it "contains the tags" do
        expect(subject).to contains_xml_node("//cac:BillingReference")
        expect(subject).to contains_xml_node("//cac:BillingReference/cac:InvoiceDocumentReference")
      end

      it "contains invoice information" do
        expect(subject).to contains_xml_node("//cac:InvoiceDocumentReference/cbc:ID").with_value(credit_note.invoice.number)
        expect(subject).to contains_xml_node("//cac:InvoiceDocumentReference/cbc:IssueDate").with_value(credit_note.invoice.issuing_date)
      end
    end

    context "when AccountingSupplierParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:AccountingSupplierParty")
      end

      it "contains the tax registration" do
        expect(subject).to contains_xml_node("//cac:AccountingSupplierParty//cac:PartyTaxScheme")
      end

      context "when credit invoice" do
        let(:invoice) { create(:invoice, invoice_type: :credit, number: "LAGO-TEST-123") }

        it "does not contains PartyTaxScheme tag" do
          expect(subject).not_to contains_xml_node("//cac:AccountingSupplierParty//cac:PartyTaxScheme")
        end
      end
    end

    context "when AccountingCustomerParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:AccountingCustomerParty")
      end
    end

    context "when PaymentMeans tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:PaymentMeans/cbc:PaymentMeansCode")
          .with_value(described_class::STANDARD_PAYMENT)
      end

      it "emits exactly one PaymentMeans block" do
        expect(subject.xpath("//cac:PaymentMeans").length).to eq(1)
      end
    end

    context "when PaymentTerms tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:PaymentTerms/cbc:Note")
          .with_value("Credit note - immediate settlement")
      end
    end

    context "when AllowanceCharge tags" do
      let(:root) { "//cac:AllowanceCharge" }

      let(:invoice_fee1) { create(:fee, invoice:, taxes_rate: 0.0, precise_coupons_amount_cents: 100, precise_amount_cents: 2000, taxes_precise_amount_cents: 0) }
      let(:invoice_fee2) { create(:fee, invoice:, taxes_rate: 5.0, precise_coupons_amount_cents: 10, precise_amount_cents: 100, taxes_precise_amount_cents: 4.75) }
      let(:invoice_fee3) { create(:fee, invoice:, taxes_rate: 5.0, precise_coupons_amount_cents: 10, precise_amount_cents: 300, taxes_precise_amount_cents: 14.25) }
      let(:invoice_fee4) { create(:fee, invoice:, taxes_rate: 10.0, precise_coupons_amount_cents: 30, precise_amount_cents: 600, taxes_precise_amount_cents: 57) }
      let(:credit_note_item1) { create(:credit_note_item, credit_note:, fee: invoice_fee1, precise_amount_cents: 1000) }
      let(:credit_note_item2) { create(:credit_note_item, credit_note:, fee: invoice_fee2, precise_amount_cents: 100) }
      let(:credit_note_item3) { create(:credit_note_item, credit_note:, fee: invoice_fee3, precise_amount_cents: 300) }
      let(:credit_note_item4) { create(:credit_note_item, credit_note:, fee: invoice_fee4, precise_amount_cents: 600) }
      let(:invoice) { create(:invoice, coupons_amount_cents: 100) }
      let(:credit_note) { create(:credit_note, invoice:, precise_coupons_adjustment_amount_cents: 100) }

      before do
        credit_note_item1
        credit_note_item2
        credit_note_item3
        credit_note_item4
      end

      it "contains all charges" do
        expect(subject.xpath(root).length).to eq(3)
      end

      # For credit_note, allowances are turned into charges
      context "with one tag per tax rate" do
        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:ChargeIndicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[1]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:Amount").with_value("0.50").with_attribute("currencyID", "EUR")
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:ID").with_value(described_class::Z_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:Percent").with_value("0.00")
        end

        it "contains 5.00% rate" do
          expect(subject).to contains_xml_node("#{root}[2]/cbc:ChargeIndicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[2]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[2]/cbc:Amount").with_value("0.20")
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:Percent").with_value("5.00")
        end

        it "contains 10.00% rate" do
          expect(subject).to contains_xml_node("#{root}[3]/cbc:ChargeIndicator").with_value(described_class::INVOICE_CHARGE)
          expect(subject).to contains_xml_node("#{root}[3]/cbc:AllowanceChargeReason")
          expect(subject).to contains_xml_node("#{root}[3]/cbc:Amount").with_value("0.30")
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:Percent").with_value("10.00")
        end
      end
    end

    context "when TaxTotal tag" do
      before do
        credit_note.update(precise_taxes_amount_cents: 1000)
      end

      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:TaxTotal")
      end

      it "contains TaxAmount tag" do
        expect(subject).to contains_xml_node("//cac:TaxTotal/cbc:TaxAmount")
          .with_value("-10.00")
          .with_attribute("currencyID", credit_note.currency)
      end
    end

    context "when TaxSubtotal tag" do
      let(:root) { "//cac:TaxTotal/cac:TaxSubtotal" }

      context "with multiple taxes" do
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

        it "contains TaxSubtotal tags" do
          expect(subject.xpath(root).length).to eq(3)
        end

        context "with one tag per tax rate" do
          it "contains 0.00% rate" do
            expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxableAmount").with_value("-10.00")
            expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxAmount").with_value("0.00")
            expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:ID").with_value(described_class::Z_CATEGORY)
            expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:Percent").with_value("0.00")
          end

          it "contains 5.00% rate" do
            expect(subject).to contains_xml_node("#{root}[2]/cbc:TaxableAmount").with_value("-4.00")
            expect(subject).to contains_xml_node("#{root}[2]/cbc:TaxAmount").with_value("-0.20")
            expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
            expect(subject).to contains_xml_node("#{root}[2]/cac:TaxCategory/cbc:Percent").with_value("5.00")
          end

          it "contains 10.00% rate" do
            expect(subject).to contains_xml_node("#{root}[3]/cbc:TaxableAmount").with_value("-6.00")
            expect(subject).to contains_xml_node("#{root}[3]/cbc:TaxAmount").with_value("-0.60")
            expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:ID").with_value(described_class::S_CATEGORY)
            expect(subject).to contains_xml_node("#{root}[3]/cac:TaxCategory/cbc:Percent").with_value("10.00")
          end
        end
      end

      context "when credit invoice" do
        let(:invoice) { create(:invoice, invoice_type: :credit) }
        let(:credit_note) { create(:credit_note, invoice:) }
        let(:fee0) { create(:fee, invoice:, fee_type: :credit, taxes_rate: 0.0, precise_amount_cents: 500, taxes_precise_amount_cents: 0) }
        let(:credit_note_item0) { create(:credit_note_item, credit_note:, fee: fee0, precise_amount_cents: 500) }

        before do
          credit_note_item0
        end

        it "contains TaxSubtotal tags" do
          expect(subject.xpath(root).length).to eq(1)
        end

        it "contains 0.00% rate" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxableAmount").with_value("-5.00")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:TaxAmount").with_value("0.00")
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:ID").with_value(described_class::O_CATEGORY)
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:TaxExemptionReasonCode").with_value(described_class::O_VAT_EXEMPTION)
          expect(subject).to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:TaxExemptionReason").with_value("Not subject to VAT")
          expect(subject).not_to contains_xml_node("#{root}[1]/cac:TaxCategory/cbc:Percent")
        end
      end
    end

    context "when LegalMonetaryTotal tag" do
      before do
        create(:credit_note_item, credit_note:, precise_amount_cents: 500)
        create(:credit_note_item, credit_note:, precise_amount_cents: 500)
        credit_note.update(precise_coupons_adjustment_amount_cents: 100, precise_taxes_amount_cents: 90)

        credit_note.reload
      end

      context "when LineExtensionAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:LineExtensionAmount")
            .with_value("-10.00")
            .with_attribute("currencyID", credit_note.currency)
        end
      end

      context "when TaxExclusiveAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount")
            .with_value("-9.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when TaxInclusiveAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount")
            .with_value("-9.90")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when AllowanceTotalAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:AllowanceTotalAmount")
            .with_value("0.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when ChargeTotalAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:ChargeTotalAmount")
            .with_value("1.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when PrepaidAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:PrepaidAmount")
            .with_value("0.00")
            .with_attribute("currencyID", invoice.currency)
        end
      end

      context "when PayableAmount tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:LegalMonetaryTotal/cbc:PayableAmount")
            .with_value("-9.90")
            .with_attribute("currencyID", invoice.currency)
        end
      end
    end

    context "when CreditNoteLine tags" do
      let(:root) { "//cac:CreditNoteLine" }

      let(:credit_note_item1) { create(:credit_note_item, credit_note:, precise_amount_cents: 100, amount: 10, fee: item_fee1) }
      let(:credit_note_item2) { create(:credit_note_item, credit_note:, precise_amount_cents: 250, amount: 25, fee: item_fee2) }
      let(:item_fee1) { create(:fee, units: 5, precise_amount_cents: 100, precise_unit_amount: 2, amount_currency: "EUR") }
      let(:item_fee2) { create(:fee, units: 1, precise_amount_cents: 250, precise_unit_amount: 25, amount_currency: "EUR") }

      before do
        credit_note_item1
        credit_note_item2
      end

      it "contains fee tags" do
        expect(subject.xpath(root).length).to eq(2)
      end

      context "with one tag per fee" do
        it "contains the first fee info" do
          expect(subject).to contains_xml_node("#{root}[1]/cbc:ID").with_value("1")
          expect(subject).to contains_xml_node("#{root}[1]/cbc:CreditedQuantity").with_value("-5.00").with_attribute("unitCode", described_class::UNIT_CODE)
          expect(subject).to contains_xml_node("#{root}[1]/cbc:LineExtensionAmount").with_value("-10.00").with_attribute("currencyID", "EUR")
        end

        it "contains the second fee info" do
          expect(subject).to contains_xml_node("#{root}[2]/cbc:ID").with_value("2")
          expect(subject).to contains_xml_node("#{root}[2]/cbc:CreditedQuantity").with_value("-1.00").with_attribute("unitCode", described_class::UNIT_CODE)
          expect(subject).to contains_xml_node("#{root}[2]/cbc:LineExtensionAmount").with_value("-25.00").with_attribute("currencyID", "EUR")
        end
      end
    end
  end
end
