# frozen_string_literal: true

module Types
  module Subscriptions
    class CreateChargeFilterInput < Types::BaseInputObject
      graphql_name "CreateSubscriptionChargeFilterInput"
      description "Create subscription charge filter input arguments"

      argument :charge_code, String, required: true
      argument :subscription_id, ID, required: true

      argument :invoice_display_name, String, required: false
      argument :properties, Types::Charges::PropertiesInput, required: true
      argument :values, Types::ChargeFilters::Values, required: true
    end
  end
end
