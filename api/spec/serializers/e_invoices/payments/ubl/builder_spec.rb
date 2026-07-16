# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Payments::Ubl::Builder do
  subject do
    xml_document(:ubl) do |xml|
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
    context "when ApplicationResponse tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//*[local-name()='ApplicationResponse']")
      end

      it "has UBLVersionID tag" do
        expect(subject).to contains_xml_node("//cbc:UBLVersionID").with_value(2.1)
      end

      it "has CustomizationID tag" do
        expect(subject).to contains_xml_node("//cbc:CustomizationID").with_value("urn:oasis:names:specification:ubl:xpath:ApplicationResponse-2.4")
      end

      it "has ProfileID tag" do
        expect(subject).to contains_xml_node("//cbc:ProfileID").with_value("urn:oasis:names:specification:ubl:schema:xsd:ApplicationResponse-2")
      end

      it "has ID tag" do
        expect(subject).to contains_xml_node("//cbc:ID").with_value(payment_receipt.number)
      end

      it "has IssueDate tag" do
        expect(subject).to contains_xml_node("//cbc:IssueDate").with_value(payment.created_at.strftime(described_class::DATEFORMAT))
      end

      it "has Note tag" do
        expect(subject).to contains_xml_node("//cbc:Note")
      end
    end

    context "when SenderParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:SenderParty")
      end
    end

    context "when ReceiverParty tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:ReceiverParty")
      end
    end

    context "when DocumentResponse tag" do
      it "contains the tag" do
        expect(subject).to contains_xml_node("//cac:DocumentResponse")
      end

      context "when Response tag" do
        it "contains the tag" do
          expect(subject).to contains_xml_node("//cac:Response")
        end

        it "contains ResponseCode tag" do
          expect(subject).to contains_xml_node("//cac:Response/cbc:ResponseCode").with_value(described_class::PAID)
        end

        it "contains Description tag" do
          expect(subject).to contains_xml_node("//cac:Response/cbc:Description")
        end

        it "contains EffectiveDate tag" do
          expect(subject).to contains_xml_node("//cac:Response/cbc:EffectiveDate").with_value(payment.created_at.strftime(described_class::DATEFORMAT))
        end
      end

      context "when DocumentReference tag" do
        it "has one tag per invoice in payment" do
          expect(
            subject.xpath(
              "//cac:DocumentReference"
            ).length
          ).to eq(payment.invoices.count)
        end

        it "has ID tag" do
          expect(subject).to contains_xml_node("//cac:DocumentReference/cbc:ID").with_value(invoice.number)
        end

        it "has IssueDate tag" do
          expect(subject).to contains_xml_node("//cac:DocumentReference/cbc:IssueDate").with_value(invoice.issuing_date.strftime(described_class::DATEFORMAT))
        end

        it "has DocumentTypeCode tag" do
          expect(subject).to contains_xml_node("//cac:DocumentReference/cbc:DocumentTypeCode").with_value(described_class::COMMERCIAL_INVOICE)
        end

        it "has DocumentType tag" do
          expect(subject).to contains_xml_node("//cac:DocumentReference/cbc:DocumentType").with_value("Invoice")
        end

        it "has DocumentDescription tag" do
          expect(subject).to contains_xml_node("//cac:DocumentReference/cbc:DocumentDescription").with_value("Invoice ID from payment system: #{invoice.id}")
        end
      end
    end
  end
end
