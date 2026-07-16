# frozen_string_literal: true

module EInvoices
  module Ubl
    class SenderParty < BaseSerializer
      delegate :billing_entity, to: :resource

      def initialize(xml:, resource:)
        super
      end

      def serialize
        xml.comment "Sender Party"
        xml["cac"].SenderParty do
          xml["cac"].PartyIdentification do
            xml["cbc"].ID billing_entity.code
          end
          xml["cac"].PartyName do
            xml["cbc"].Name billing_entity.name
          end
          xml["cac"].PostalAddress do
            xml["cbc"].StreetName billing_entity.address_line1
            xml["cbc"].AdditionalStreetName billing_entity.address_line2 if billing_entity.address_line2.present?
            xml["cbc"].CityName billing_entity.city
            xml["cbc"].PostalZone billing_entity.zipcode
            xml["cac"].Country do
              xml["cbc"].IdentificationCode billing_entity.country
            end
          end
          xml["cac"].PartyTaxScheme do
            xml["cbc"].CompanyID billing_entity.tax_identification_number
            xml["cac"].TaxScheme do
              xml["cbc"].ID VAT
            end
          end
          xml["cac"].Contact do
            xml["cbc"].Name billing_entity.name
            xml["cbc"].ElectronicMail billing_entity.email
          end
        end
      end
    end
  end
end
