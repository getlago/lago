# frozen_string_literal: true

module Types
  module Charges
    class Input < Types::BaseInputObject
      graphql_name "ChargeInput"

      argument :billable_metric_id, ID, required: true
      argument :charge_model, Types::Charges::ChargeModelEnum, required: true
      argument :id, ID, required: false
      argument :invoice_display_name, String, required: false
      argument :invoiceable, Boolean, required: false
      argument :min_amount_cents, GraphQL::Types::BigInt, required: false
      argument :pay_in_advance, Boolean, required: false
      argument :prorated, Boolean, required: false
      argument :regroup_paid_fees, Types::Charges::RegroupPaidFeesEnum, required: false

      argument :filters, [Types::ChargeFilters::Input], required: false
      argument :properties, Types::Charges::PropertiesInput, required: false

      argument :applied_pricing_unit, Types::AppliedPricingUnits::Input, required: false
      argument :tax_codes, [String], required: false
    end
  end
end
