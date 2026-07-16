# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::DocumentResponse do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, response:, document:)
    end
  end

  let(:invoice) { create(:invoice) }
  let(:response) do
    described_class::Response.new(
      code: described_class::PAID,
      description: "This is a test response PD",
      date: "2025-03-16".to_date
    )
  end
  let(:document) do
    described_class::Document.new(
      id: invoice.id,
      issue_date: invoice.issuing_date,
      type_code: described_class::COMMERCIAL_INVOICE,
      type: "Invoice",
      description: "Original invoice reference: #{invoice.id}"
    )
  end

  let(:root) { "//cac:DocumentResponse" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Document Response")
    end

    it "contains DocumentResponse tag" do
      expect(subject).to contains_xml_node(root)
    end

    context "with Response" do
      let(:xpath) { "#{root}/cac:Response" }

      it "expects to have ResponseCode" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:ResponseCode").with_value(response.code)
      end

      it "expects to have Description" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:Description").with_value(response.description)
      end

      it "expects to have EffectiveDate" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:EffectiveDate").with_value("2025-03-16")
      end
    end

    context "with DocumentReference" do
      let(:xpath) { "#{root}/cac:DocumentReference" }

      it "expects to have ID" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:ID").with_value(document.id)
      end

      it "expects to have IssueDate" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:IssueDate").with_value(document.issue_date)
      end

      it "expects to have DocumentTypeCode" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:DocumentTypeCode").with_value(document.type_code)
      end

      it "expects to have DocumentType" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:DocumentType").with_value(document.type)
      end

      it "expects to have DocumentDescription" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:DocumentDescription").with_value(document.description)
      end
    end
  end
end
