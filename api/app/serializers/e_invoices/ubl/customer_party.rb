# frozen_string_literal: true

module EInvoices
  module Ubl
    class CustomerParty < BaseSerializer
      delegate :customer, to: :resource

      def serialize
        xml.comment "Customer Party"
        xml["cac"].AccountingCustomerParty do
          xml["cac"].Party do
            xml["cbc"].EndpointID customer.email, schemeID: "EM" if customer.email.present?
            xml["cac"].PostalAddress do
              xml["cbc"].StreetName customer.address_line1
              xml["cbc"].AdditionalStreetName customer.address_line2 if customer.address_line2.present?
              xml["cbc"].CityName customer.city
              xml["cbc"].PostalZone customer.zipcode
              xml["cac"].Country do
                xml["cbc"].IdentificationCode customer.country
              end
            end
            xml["cac"].PartyLegalEntity do
              xml["cbc"].RegistrationName customer.name
            end
            xml["cac"].Contact do
              xml["cbc"].Name customer.name
              xml["cbc"].ElectronicMail customer.email if customer.email.present?
            end
          end
        end
      end
    end
  end
end
