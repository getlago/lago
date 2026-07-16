# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::TradeAgreement do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, resource:, options:)
    end
  end

  let(:options) { described_class::Options.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:resource) { create(:invoice, customer:, organization:, billing_entity:, invoice_type:) }
  let(:invoice_type) { :subscription }
  let(:customer) do
    create(:customer,
      organization:,
      name: "Its Mii",
      legal_name: nil)
  end
  let(:billing_entity) do
    create(:billing_entity,
      organization:,
      code: "BE_CODE",
      legal_name: "BE Legal Name",
      zipcode: "60192460",
      address_line1: "Rue quelque part",
      address_line2: "Tourne au deuxième angle",
      city: "Eine Stadt",
      country: "BR",
      tax_identification_number: "BR987654321")
  end

  let(:root) { "//ram:ApplicableHeaderTradeAgreement" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Applicable Header Trade Agreement")
    end

    context "with seller information" do
      let(:seller_root) { "#{root}/ram:SellerTradeParty" }

      it "have the line id" do
        expect(subject).to contains_xml_node("#{seller_root}/ram:ID")
          .with_value(billing_entity.code)
      end

      it "have the name" do
        expect(subject).to contains_xml_node("#{seller_root}/ram:Name")
          .with_value(billing_entity.legal_name)
      end

      context "when address info" do
        let(:seller_address_root) { "#{seller_root}/ram:PostalTradeAddress" }

        it "have the address" do
          expect(subject).to contains_xml_node("#{seller_address_root}/ram:PostcodeCode")
            .with_value(billing_entity.zipcode)
          expect(subject).to contains_xml_node("#{seller_address_root}/ram:LineOne")
            .with_value(billing_entity.address_line1)
          expect(subject).to contains_xml_node("#{seller_address_root}/ram:LineTwo")
            .with_value(billing_entity.address_line2)
          expect(subject).to contains_xml_node("#{seller_address_root}/ram:CityName")
            .with_value(billing_entity.city)
          expect(subject).to contains_xml_node("#{seller_address_root}/ram:CountryID")
            .with_value(billing_entity.country)
        end
      end

      context "when tax info" do
        let(:seller_tax_root) { "#{seller_root}/ram:SpecifiedTaxRegistration" }

        it "have the tax id" do
          expect(subject).to contains_xml_node("#{seller_tax_root}/ram:ID")
            .with_value(billing_entity.tax_identification_number)
            .with_attribute("schemeID", "VA")
        end

        context "with tax_registration false" do
          let(:options) { described_class::Options.new(tax_registration: false) }

          it "dont have the tax id" do
            expect(subject).not_to contains_xml_node("#{seller_tax_root}/ram:ID")
          end
        end
      end
    end

    context "when buyer information" do
      let(:buyer_root) { "#{root}/ram:BuyerTradeParty" }

      context "when customer has no legal_name" do
        it "falls back to the customer name" do
          expect(customer.legal_name).to be_nil
          expect(subject).to contains_xml_node("#{buyer_root}/ram:Name")
            .with_value(customer.name)
        end
      end

      context "when customer has a legal_name" do
        before { customer.update(legal_name: "Mii Industries SARL") }

        it "uses the legal_name instead of the name" do
          expect(subject).to contains_xml_node("#{buyer_root}/ram:Name")
            .with_value(customer.legal_name)
        end
      end

      context "when address info" do
        let(:buyer_address_root) { "#{buyer_root}/ram:PostalTradeAddress" }

        it "have the address" do
          expect(subject).to contains_xml_node("#{buyer_address_root}/ram:PostcodeCode")
            .with_value(customer.zipcode)
          expect(subject).to contains_xml_node("#{buyer_address_root}/ram:LineOne")
            .with_value(customer.address_line1)
          expect(subject).to contains_xml_node("#{buyer_address_root}/ram:LineTwo")
            .with_value(customer.address_line2)
          expect(subject).to contains_xml_node("#{buyer_address_root}/ram:CityName")
            .with_value(customer.city)
          expect(subject).to contains_xml_node("#{buyer_address_root}/ram:CountryID")
            .with_value(customer.country)
        end
      end
    end

    context "with a purchase order number" do
      before { resource.update!(purchase_order_number: "PO-12345") }

      it "contains the BuyerOrderReferencedDocument" do
        expect(subject).to contains_xml_node("#{root}/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID")
          .with_value("PO-12345")
      end
    end

    context "without a purchase order number" do
      it "does not contain the BuyerOrderReferencedDocument" do
        expect(subject).not_to contains_xml_node("#{root}/ram:BuyerOrderReferencedDocument")
      end
    end
  end
end
