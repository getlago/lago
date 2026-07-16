# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::InvoiceReference do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, invoice_reference:) do
      end
    end
  end

  let(:invoice_reference) { "TES-ABCD-202510-001" }

  let(:root) { "//ram:InvoiceReferencedDocument" }

  describe ".call" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Invoice reference")
    end

    it "have Description" do
      expect(subject).to contains_xml_node("#{root}/ram:IssuerAssignedID")
        .with_value(invoice_reference)
    end
  end
end
