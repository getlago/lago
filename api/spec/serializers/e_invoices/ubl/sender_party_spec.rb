# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::SenderParty do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:)
    end
  end

  let(:resource) { create(:payment, customer:) }
  let(:customer) { create(:customer, billing_entity:) }
  let(:billing_entity) do
    create(
      :billing_entity,
      code: "test_be",
      name: "Test BE",
      address_line1: "Somewhere",
      address_line2: "Far Beyond",
      city: "A City",
      zipcode: "1234-FE",
      country: "BR",
      tax_identification_number: "1234BR5678",
      email: "lago-be@test.com"
    )
  end

  let(:root) { "//cac:SenderParty" }

  before { resource }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Sender Party")
    end

    it "contains PartyIdentification tag" do
      expect(subject).to contains_xml_node("#{root}/cac:PartyIdentification/cbc:ID").with_value(billing_entity.code)
    end

    it "contains PartyName tag" do
      expect(subject).to contains_xml_node("#{root}/cac:PartyName/cbc:Name").with_value(billing_entity.name)
    end

    context "with PostalAddress" do
      let(:xpath) { "#{root}/cac:PostalAddress" }

      it "expects to have street name" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:StreetName").with_value(billing_entity.address_line1)
        expect(subject).to contains_xml_node("#{xpath}/cbc:AdditionalStreetName").with_value(billing_entity.address_line2)
      end

      context "when address_line2 is blank" do
        before { billing_entity.update!(address_line2: nil) }

        it "omits AdditionalStreetName" do
          expect(subject).not_to contains_xml_node("#{xpath}/cbc:AdditionalStreetName")
        end
      end

      it "expects to have city" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:CityName").with_value(billing_entity.city)
      end

      it "expects to have zipcode" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:PostalZone").with_value(billing_entity.zipcode)
      end

      it "expects to have country" do
        expect(subject).to contains_xml_node("#{xpath}/cac:Country/cbc:IdentificationCode")
          .with_value(billing_entity.country)
      end
    end

    context "with PartyTaxScheme" do
      let(:xpath) { "#{root}/cac:PartyTaxScheme" }

      it "expects to have company id" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:CompanyID").with_value(billing_entity.tax_identification_number)
      end

      it "expects to have tax scheme id" do
        expect(subject).to contains_xml_node("#{xpath}/cac:TaxScheme/cbc:ID").with_value("VAT")
      end
    end

    it "contains Contact tag" do
      expect(subject).to contains_xml_node("#{root}/cac:Contact/cbc:Name").with_value(billing_entity.name)
      expect(subject).to contains_xml_node("#{root}/cac:Contact/cbc:ElectronicMail").with_value(billing_entity.email)
    end
  end
end
