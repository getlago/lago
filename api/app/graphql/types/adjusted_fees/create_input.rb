# frozen_string_literal: true

module Types
  module AdjustedFees
    class CreateInput < Types::BaseInputObject
      description "Create Adjusted Fee Input"

      argument :invoice_id, ID, required: true

      # NOTE: adjust an existing fee
      argument :fee_id, ID, required: false

      # NOTE: adjust a empty charge or fixed charge fee
      argument :charge_filter_id, ID, required: false
      argument :charge_id, ID, required: false
      argument :fixed_charge_id, ID, required: false
      argument :subscription_id, ID, required: false

      argument :invoice_display_name, String, required: false
      argument :invoice_subscription_id, ID, required: false
      argument :unit_precise_amount, String, required: false
      argument :units, GraphQL::Types::Float, required: false
    end
  end
end
