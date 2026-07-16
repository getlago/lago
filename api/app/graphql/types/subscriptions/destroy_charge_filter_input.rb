# frozen_string_literal: true

module Types
  module Subscriptions
    class DestroyChargeFilterInput < Types::BaseInputObject
      graphql_name "DestroySubscriptionChargeFilterInput"
      description "Destroy subscription charge filter input arguments"

      argument :charge_code, String, required: true
      argument :subscription_id, ID, required: true
      argument :values, Types::ChargeFilters::Values, required: true
    end
  end
end
