# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::SupplierParty do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, resource:, options:)
    end
  end

  let(:options) { described_class::Options.new }
  let(:resource) { invoice }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invoice) { create(:invoice, organization:, billing_entity:, invoice_type:) }
  let(:invoice_type) { :subscription }
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

  let(:root) { "//cac:AccountingSupplierParty/cac:Party" }

  before { invoice }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Supplier Party")
    end

    context "with billing entity" do
      context "with EndpointID" do
        let(:xpath) { "#{root}/cbc:EndpointID" }

        it "emits the seller email with schemeID EM (BR-CO-26)" do
          expect(subject).to contains_xml_node(xpath)
            .with_value(billing_entity.email)
            .with_attribute("schemeID", "EM")
        end

        context "when billing entity has no email" do
          before { billing_entity.update!(email: nil) }

          it "omits EndpointID" do
            expect(subject).not_to contains_xml_node(xpath)
          end
        end
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

        context "with tax_registration as false" do
          let(:options) { described_class::Options.new(tax_registration: false) }

          it "does not have the tag" do
            expect(subject).not_to contains_xml_node("#{root}/cac:PartyTaxScheme")
          end
        end
      end

      context "with Contact" do
        let(:xpath) { "#{root}/cac:Contact" }

        it "emits the seller Name and ElectronicMail" do
          expect(subject).to contains_xml_node("#{xpath}/cbc:Name")
            .with_value(billing_entity.name)
          expect(subject).to contains_xml_node("#{xpath}/cbc:ElectronicMail")
            .with_value(billing_entity.email)
        end

        context "with a German billing entity" do
          before { billing_entity.update!(country: "DE", phone: "+49 30 1234-5678") }

          it "emits the billing entity's phone as Telephone" do
            expect(subject).to contains_xml_node("#{xpath}/cbc:Telephone")
              .with_value("+49 30 1234-5678")
          end
        end

        context "with a non-DE billing entity" do
          before { billing_entity.update!(country: "FR") }

          it "does not emit Telephone" do
            expect(subject).not_to contains_xml_node("#{xpath}/cbc:Telephone")
          end
        end

        context "when billing entity has no email" do
          before { billing_entity.update!(email: nil) }

          it "still emits Name but omits ElectronicMail" do
            expect(subject).to contains_xml_node("#{xpath}/cbc:Name")
              .with_value(billing_entity.name)
            expect(subject).not_to contains_xml_node("#{xpath}/cbc:ElectronicMail")
          end
        end
      end

      context "with PartyLegalEntity" do
        let(:xpath) { "#{root}/cac:PartyLegalEntity" }

        it "expects to have registration name" do
          expect(subject).to contains_xml_node("#{xpath}/cbc:RegistrationName").with_value(billing_entity.legal_name)
        end

        it "expects to have company id" do
          expect(subject).to contains_xml_node("#{xpath}/cbc:CompanyID").with_value(billing_entity.tax_identification_number)
        end
      end
    end
  end
end
