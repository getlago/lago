# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::OrderReference do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, id: purchase_order_number)
    end
  end

  let(:purchase_order_number) { "PO-12345" }
  let(:root) { "//cac:OrderReference" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Order Reference")
    end

    it "has the purchase order number as ID" do
      expect(subject).to contains_xml_node("#{root}/cbc:ID").with_value(purchase_order_number)
    end
  end
end
