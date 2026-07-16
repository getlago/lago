# frozen_string_literal: true

module Types
  module Customers
    class AddressInput < BaseInputObject
      graphql_name "CustomerAddressInput"

      argument :address_line1, String, required: false
      argument :address_line2, String, required: false
      argument :city, String, required: false
      argument :country, Types::CountryCodeEnum, required: false
      argument :state, String, required: false
      argument :zipcode, String, required: false
    end
  end
end
