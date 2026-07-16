# frozen_string_literal: true

module Types
  module ChargeFilters
    class Input < BaseInputObject
      graphql_name "ChargeFilterInput"
      description "Charge filters input arguments"

      argument :invoice_display_name, String, required: false
      argument :properties, Types::Charges::PropertiesInput, required: true
      argument :values, Types::ChargeFilters::Values, required: true
    end
  end
end
