# frozen_string_literal: true

module Types
  module Subscriptions
    class ChargeOverridesInput < Types::BaseInputObject
      argument :billable_metric_id, ID, required: true
      argument :id, ID, required: false

      argument :applied_pricing_unit, Types::AppliedPricingUnits::OverrideInput, required: false
      argument :filters, [Types::ChargeFilters::Input], required: false
      argument :invoice_display_name, String, required: false
      argument :min_amount_cents, GraphQL::Types::BigInt, required: false
      argument :properties, Types::Charges::PropertiesInput, required: false
      argument :tax_codes, [String], required: false
    end
  end
end
