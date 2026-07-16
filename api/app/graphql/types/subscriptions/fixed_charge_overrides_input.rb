# frozen_string_literal: true

module Types
  module Subscriptions
    class FixedChargeOverridesInput < Types::BaseInputObject
      argument :add_on_id, ID, required: false
      argument :id, ID, required: false

      argument :apply_units_immediately, Boolean, required: false
      argument :invoice_display_name, String, required: false
      argument :properties, Types::FixedCharges::PropertiesInput, required: false
      argument :tax_codes, [String], required: false
      argument :units, String, required: false
    end
  end
end
