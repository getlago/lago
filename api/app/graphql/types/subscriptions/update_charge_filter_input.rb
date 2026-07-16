# frozen_string_literal: true

module Types
  module Subscriptions
    class UpdateChargeFilterInput < Types::BaseInputObject
      graphql_name "UpdateSubscriptionChargeFilterInput"
      description "Update subscription charge filter input arguments"

      argument :charge_code, String, required: true
      argument :subscription_id, ID, required: true
      argument :values, Types::ChargeFilters::Values, required: true

      argument :invoice_display_name, String, required: false
      argument :properties, Types::Charges::PropertiesInput, required: false
    end
  end
end
