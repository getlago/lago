# frozen_string_literal: true

module Types
  module Plans
    class CreateInput < Types::BaseInputObject
      graphql_name "CreatePlanInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: true
      argument :amount_currency, Types::CurrencyEnum
      argument :bill_charges_monthly, Boolean, required: false
      argument :bill_fixed_charges_monthly, Boolean, required: false
      argument :code, String, required: true
      argument :description, String, required: false
      argument :interval, Types::Plans::IntervalEnum, required: true
      argument :invoice_display_name, String, required: false
      argument :metadata, [Types::Metadata::Input], required: false, **Types::Metadata::Input::ARGUMENT_OPTIONS
      argument :name, String, required: true
      argument :pay_in_advance, Boolean, required: true
      argument :tax_codes, [String], required: false
      argument :trial_period, Float, required: false

      argument :charges, [Types::Charges::Input]
      argument :fixed_charges, [Types::FixedCharges::Input], required: false
      argument :minimum_commitment, Types::Commitments::Input, required: false

      argument :usage_thresholds, [Types::UsageThresholds::Input], required: false

      argument :entitlements, [Types::Entitlement::EntitlementInput], required: false
    end
  end
end
