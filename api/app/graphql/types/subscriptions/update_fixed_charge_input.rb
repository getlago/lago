# frozen_string_literal: true

module Types
  module Subscriptions
    class UpdateFixedChargeInput < Types::BaseInputObject
      argument :fixed_charge_code, String, required: true
      argument :subscription_id, ID, required: true

      argument :apply_units_immediately, Boolean, required: false
      argument :invoice_display_name, String, required: false
      argument :properties, Types::FixedCharges::PropertiesInput, required: false
      argument :tax_codes, [String], required: false
      argument :units, String, required: false
    end
  end
end
