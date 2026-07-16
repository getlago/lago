# frozen_string_literal: true

module Types
  module FixedCharges
    class CreateInput < Types::BaseInputObject
      graphql_name "FixedChargeCreateInput"

      argument :plan_id, ID, required: true

      argument :add_on_id, ID, required: true
      argument :apply_units_immediately, Boolean, required: false
      argument :charge_model, Types::FixedCharges::ChargeModelEnum, required: true
      argument :code, String, required: false
      argument :invoice_display_name, String, required: false
      argument :pay_in_advance, Boolean, required: false
      argument :prorated, Boolean, required: false
      argument :units, String, required: false

      argument :properties, Types::FixedCharges::PropertiesInput, required: false

      argument :cascade_updates, Boolean, required: false
      argument :tax_codes, [String], required: false
    end
  end
end
