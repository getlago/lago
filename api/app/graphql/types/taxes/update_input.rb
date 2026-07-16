# frozen_string_literal: true

module Types
  module Taxes
    class UpdateInput < Types::BaseInputObject
      graphql_name "TaxUpdateInput"

      argument :code, String, required: false
      argument :description, String, required: false
      argument :id, ID, required: true
      argument :name, String, required: false
      argument :rate, Float, required: false

      argument :applied_to_organization, Boolean, required: false
    end
  end
end
