# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::LineItem do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:, data:)
    end
  end

  let(:resource) { nil }
  let(:data_type) { :invoice }
  let(:item_category) { described_class::S_CATEGORY }
  let(:item_rate_percent) { 20.0 }
  let(:data) do
    described_class::Data.new(
      type: data_type,
      line_id: 1,
      quantity: 2,
      line_extension_amount: 0.118,
      currency: "USD",
      item_name: "item name",
      item_category:,
      item_rate_percent:,
      item_description: "fee description",
      price_amount: 0.059
    )
  end

  let(:root) { "//cac:InvoiceLine" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Line Item 1: fee description")
    end

    it "have the line id" do
      expect(subject).to contains_xml_node("#{root}/cbc:ID").with_value(1)
    end

    context "with item units" do
      context "when InvoicedQuantity" do
        it "have the item units" do
          expect(subject).to contains_xml_node("#{root}/cbc:InvoicedQuantity").with_value("2.00").with_attribute("unitCode", "C62")
        end
      end

      context "when CreditedQuantity" do
        let(:data_type) { :credit_note }
        let(:root) { "//cac:CreditNoteLine" }

        it "have the item units" do
          expect(subject).to contains_xml_node("#{root}/cbc:CreditedQuantity").with_value("2.00").with_attribute("unitCode", "C62")
        end
      end
    end

    it "have the item total amount" do
      expect(subject).to contains_xml_node("#{root}/cbc:LineExtensionAmount").with_value("0.12").with_attribute("currencyID", "USD")
    end

    context "when Item" do
      it "have the item name" do
        expect(subject).to contains_xml_node("#{root}/cac:Item/cbc:Name").with_value("item name")
      end

      context "with ClassifiedTaxCategory" do
        context "with Category ID" do
          let(:xpath) { "#{root}/cac:Item/cac:ClassifiedTaxCategory/cbc:ID" }

          it "has the category code" do
            expect(subject).to contains_xml_node(xpath).with_value("S")
          end
        end

        context "when Percent" do
          it "have the item taxes rate" do
            expect(subject).to contains_xml_node(
              "#{root}/cac:Item/cac:ClassifiedTaxCategory/cbc:Percent"
            ).with_value("20.0")
          end

          context "with outside of tax range" do
            let(:item_rate_percent) { nil }

            it "do not have percent tag" do
              expect(subject).not_to contains_xml_node(
                "#{root}/cac:Item/cac:ClassifiedTaxCategory/cbc:Percent"
              )
            end
          end
        end

        it "have the item taxes scheme" do
          expect(subject).to contains_xml_node(
            "#{root}/cac:Item/cac:ClassifiedTaxCategory/cac:TaxScheme/cbc:ID"
          ).with_value("VAT")
        end
      end

      context "when AdditionalItemProperty" do
        it "have the item description" do
          expect(subject).to contains_xml_node(
            "#{root}/cac:Item/cac:AdditionalItemProperty/cbc:Name"
          ).with_value("Description")

          expect(subject).to contains_xml_node(
            "#{root}/cac:Item/cac:AdditionalItemProperty/cbc:Value"
          ).with_value("fee description")
        end
      end
    end

    context "when Price" do
      it "have the item unit amount" do
        expect(subject).to contains_xml_node("#{root}/cac:Price/cbc:PriceAmount")
          .with_value("0.059")
          .with_attribute("currencyID", "USD")
      end
    end
  end
end
