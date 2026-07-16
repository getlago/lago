# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::PaymentTerms do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, note:)
    end
  end

  let(:note) { "Payment term 1 days" }

  let(:root) { "//cac:PaymentTerms" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Payment Terms")
    end

    it "have Note with payment term days" do
      expect(subject).to contains_xml_node("#{root}/cbc:Note").with_value(note)
    end
  end
end
