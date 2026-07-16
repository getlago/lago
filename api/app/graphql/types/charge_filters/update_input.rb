# frozen_string_literal: true

module Types
  module ChargeFilters
    class UpdateInput < BaseInputObject
      graphql_name "ChargeFilterUpdateInput"
      description "Charge filter update input arguments"

      argument :id, ID, required: true

      argument :cascade_updates, Boolean, required: false
      argument :invoice_display_name, String, required: false
      argument :properties, Types::Charges::PropertiesInput, required: false
    end
  end
end
