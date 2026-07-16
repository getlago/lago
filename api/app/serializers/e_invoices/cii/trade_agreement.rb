# frozen_string_literal: true

module EInvoices
  module Cii
    class TradeAgreement < BaseSerializer
      Options = Data.define(:tax_registration) do
        def initialize(tax_registration: true)
          super
        end
      end

      TAX_SCHEMA_ID = "VA"

      delegate :billing_entity, to: :resource
      delegate :customer, to: :resource

      def initialize(xml:, resource:, options: Options.new)
        super(xml:, resource:)

        @options = options
      end

      def serialize
        xml.comment "Applicable Header Trade Agreement"
        xml["ram"].ApplicableHeaderTradeAgreement do
          xml["ram"].SellerTradeParty do
            xml["ram"].ID billing_entity.code
            xml["ram"].Name billing_entity.legal_name
            xml["ram"].PostalTradeAddress do
              xml["ram"].PostcodeCode billing_entity.zipcode
              xml["ram"].LineOne billing_entity.address_line1
              xml["ram"].LineTwo billing_entity.address_line2
              xml["ram"].CityName billing_entity.city
              xml["ram"].CountryID billing_entity.country
            end
            if render_tax_registration?
              xml["ram"].SpecifiedTaxRegistration do
                xml["ram"].ID billing_entity.tax_identification_number, schemeID: TAX_SCHEMA_ID
              end
            end
          end
          xml["ram"].BuyerTradeParty do
            xml["ram"].Name customer.legal_name || customer.name
            xml["ram"].PostalTradeAddress do
              xml["ram"].PostcodeCode customer.zipcode
              xml["ram"].LineOne customer.address_line1
              xml["ram"].LineTwo customer.address_line2
              xml["ram"].CityName customer.city
              xml["ram"].CountryID customer.country
            end
          end
          if purchase_order_number.present?
            xml["ram"].BuyerOrderReferencedDocument do
              xml["ram"].IssuerAssignedID purchase_order_number
            end
          end
        end
      end

      private

      attr_accessor :options

      def purchase_order_number
        resource.try(:purchase_order_number)
      end

      def render_tax_registration?
        options && !!options.tax_registration
      end
    end
  end
end
