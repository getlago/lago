# frozen_string_literal: true

module Types
  module CustomerPortal
    module Customers
      class UpdateInput < BaseInputObject
        graphql_name "UpdateCustomerPortalCustomerInput"
        description "Customer Portal Customer Update input arguments"

        argument :customer_type, Types::Customers::CustomerTypeEnum, required: false
        argument :document_locale, String, required: false
        argument :email, String, required: false
        argument :firstname, String, required: false
        argument :lastname, String, required: false
        argument :legal_name, String, required: false
        argument :name, String, required: false
        argument :tax_identification_number, String, required: false

        # Billing address
        argument :address_line1, String, required: false
        argument :address_line2, String, required: false
        argument :city, String, required: false
        argument :country, Types::CountryCodeEnum, required: false
        argument :state, String, required: false
        argument :zipcode, String, required: false

        argument :shipping_address, Types::Customers::AddressInput, required: false
      end
    end
  end
end
