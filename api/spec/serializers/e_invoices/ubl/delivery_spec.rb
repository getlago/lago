# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::Delivery do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, delivery_date:)
    end
  end

  let(:resource) { invoice }
  let(:delivery_date) { "2025-03-16".to_date }

  let(:root) { "//cac:Delivery" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Delivery Information")
    end

    context "when OccurrenceDateTime" do
      let(:xpath) { "#{root}/cbc:ActualDeliveryDate" }

      it "have the delivery_date" do
        expect(subject).to contains_xml_node(xpath).with_value(delivery_date)
      end
    end
  end
end
