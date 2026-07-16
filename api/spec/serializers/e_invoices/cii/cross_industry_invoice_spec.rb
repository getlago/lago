# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::CrossIndustryInvoice do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:) do
      end
    end
  end

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Exchange Document Context")
    end

    context "with ExchangedDocumentContext tag" do
      it "have the document schema version number" do
        expect(subject).to contains_xml_node(
          "//rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID"
        ).with_value("urn:cen.eu:en16931:2017")
      end
    end
  end
end
