# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::BillingReference do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:)
    end
  end

  let(:resource) { invoice }
  let(:issuing_date) { "2025-03-16".to_date }
  let(:invoice) { create(:invoice, issuing_date:) }
  let(:root) { "//cac:BillingReference" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Reference to Original Invoice")
    end

    context "when InvoiceDocumentReference" do
      let(:xpath) { "#{root}/cac:InvoiceDocumentReference" }

      it "have the ID" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:ID").with_value(invoice.number)
      end

      it "have the IssueDate" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:IssueDate").with_value(invoice.issuing_date)
      end
    end
  end
end
