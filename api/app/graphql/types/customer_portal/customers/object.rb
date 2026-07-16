# frozen_string_literal: true

module Types
  module CustomerPortal
    module Customers
      class Object < Types::BaseObject
        graphql_name "CustomerPortalCustomer"

        field :id, ID, null: false

        field :account_type, Types::Customers::AccountTypeEnum, null: false
        field :applicable_timezone, Types::TimezoneEnum, null: false
        field :currency, Types::CurrencyEnum, null: true
        field :customer_type, Types::Customers::CustomerTypeEnum
        field :display_name, String, null: false
        field :email, String, null: true
        field :firstname, String
        field :lastname, String
        field :legal_name, String, null: true
        field :legal_number, String, null: true
        field :name, String
        field :tax_identification_number, String, null: true

        field :billing_configuration, Types::Customers::BillingConfiguration, null: true
        field :billing_entity_billing_configuration, Types::BillingEntities::BillingConfiguration, null: false

        # Billing address
        field :address_line1, String, null: true
        field :address_line2, String, null: true
        field :city, String, null: true
        field :country, Types::CountryCodeEnum, null: true
        field :state, String, null: true
        field :zipcode, String, null: true

        field :shipping_address, Types::Customers::Address, null: true

        field :premium, Boolean, null: false

        def billing_configuration
          {
            id: "#{object&.id}-c0nf",
            document_locale: object&.document_locale
          }
        end

        def billing_entity_billing_configuration
          {
            id: "#{object&.billing_entity&.id}-c1nf",
            document_locale: object&.billing_entity&.document_locale
          }
        end

        def premium
          License.premium?
        end
      end
    end
  end
end
