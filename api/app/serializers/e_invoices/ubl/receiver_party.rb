# frozen_string_literal: true

module EInvoices
  module Ubl
    class ReceiverParty < BaseSerializer
      delegate :customer, to: :resource

      def initialize(xml:, resource:)
        super
      end

      def serialize
        xml.comment "Receiver Party"
        xml["cac"].ReceiverParty do
          xml["cac"].PartyName do
            xml["cbc"].Name customer.name
          end
          xml["cac"].PostalAddress do
            xml["cbc"].StreetName customer.address_line1
            xml["cbc"].AdditionalStreetName customer.address_line2 if customer.address_line2.present?
            xml["cbc"].CityName customer.city
            xml["cbc"].PostalZone customer.zipcode
            xml["cac"].Country do
              xml["cbc"].IdentificationCode customer.country
            end
          end
        end
      end
    end
  end
end
