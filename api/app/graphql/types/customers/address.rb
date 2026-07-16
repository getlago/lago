# frozen_string_literal: true

module Types
  module Customers
    class Address < Types::BaseObject
      graphql_name "CustomerAddress"

      field :address_line1, String, null: true
      field :address_line2, String, null: true
      field :city, String, null: true
      field :country, Types::CountryCodeEnum, null: true
      field :state, String, null: true
      field :zipcode, String, null: true
    end
  end
end
