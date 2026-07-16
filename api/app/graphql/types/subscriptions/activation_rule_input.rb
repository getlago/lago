# frozen_string_literal: true

module Types
  module Subscriptions
    class ActivationRuleInput < Types::BaseInputObject
      graphql_name "SubscriptionActivationRuleInput"

      argument :id, ID, required: false
      argument :timeout_hours, Integer, required: false
      argument :type, Types::Subscriptions::ActivationRuleTypeEnum, required: true
    end
  end
end
