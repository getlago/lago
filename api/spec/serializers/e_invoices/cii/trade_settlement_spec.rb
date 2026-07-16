# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::TradeSettlement do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, resource:) do
      end
    end
  end

  let(:resource) { create(:invoice, currency: "EUR") }

  let(:root) { "//ram:ApplicableHeaderTradeSettlement" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Applicable Header Trade Settlement")
    end

    it "have the invoice currency" do
      expect(subject).to contains_xml_node("#{root}/ram:InvoiceCurrencyCode")
        .with_value("EUR")
    end

    context "when resource is credit note" do
      let(:resource) { create(:credit_note, total_amount_currency: "EUR") }

      it "have the invoice currency" do
        expect(subject).to contains_xml_node("#{root}/ram:InvoiceCurrencyCode")
          .with_value("EUR")
      end
    end
  end
end
