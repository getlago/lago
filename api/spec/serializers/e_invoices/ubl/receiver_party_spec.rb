# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::ReceiverParty do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:)
    end
  end

  let(:resource) { create(:payment, customer:) }
  let(:customer) do
    create(
      :customer,
      name: "Customer Jr",
      address_line1: "Somewhere",
      address_line2: "Turn around, wrong way",
      city: "Some city",
      zipcode: "09876 CE",
      country: "BR"
    )
  end

  let(:root) { "//cac:ReceiverParty" }

  before { resource }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Receiver Party")
    end

    it "contains PartyName tag" do
      expect(subject).to contains_xml_node("#{root}/cac:PartyName/cbc:Name").with_value(customer.name)
    end

    context "with PostalAddress" do
      let(:xpath) { "#{root}/cac:PostalAddress" }

      it "expects to have street name" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:StreetName").with_value(customer.address_line1)
        expect(subject).to contains_xml_node("#{xpath}/cbc:AdditionalStreetName").with_value(customer.address_line2)
      end

      context "when address_line2 is blank" do
        before { customer.update!(address_line2: nil) }

        it "omits AdditionalStreetName" do
          expect(subject).not_to contains_xml_node("#{xpath}/cbc:AdditionalStreetName")
        end
      end

      it "expects to have city" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:CityName").with_value(customer.city)
      end

      it "expects to have zipcode" do
        expect(subject).to contains_xml_node("#{xpath}/cbc:PostalZone").with_value(customer.zipcode)
      end

      it "expects to have country" do
        expect(subject).to contains_xml_node("#{xpath}/cac:Country/cbc:IdentificationCode")
          .with_value(customer.country)
      end
    end
  end
end
