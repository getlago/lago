# frozen_string_literal: true

module Types
  module ChargeFilters
    class CreateInput < BaseInputObject
      graphql_name "ChargeFilterCreateInput"
      description "Charge filter create input arguments"

      argument :charge_id, ID, required: true

      argument :cascade_updates, Boolean, required: false
      argument :invoice_display_name, String, required: false
      argument :properties, Types::Charges::PropertiesInput, required: true
      argument :values, Types::ChargeFilters::Values, required: true
    end
  end
end
