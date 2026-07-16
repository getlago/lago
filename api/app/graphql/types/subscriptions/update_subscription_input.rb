# frozen_string_literal: true

module Types
  module Subscriptions
    class UpdateSubscriptionInput < BaseInputObject
      description "Update Subscription input arguments"

      argument :id, ID, required: true

      argument :activation_rules, [Types::Subscriptions::ActivationRuleInput], required: false
      argument :billing_entity_id, ID, required: false
      argument :consolidate_invoice, Boolean, required: false
      argument :ending_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :invoice_custom_section, Types::InvoiceCustomSections::ReferenceInput, required: false
      argument :name, String, required: false
      argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
      argument :plan_overrides, Types::Subscriptions::PlanOverridesInput, required: false
      argument :progressive_billing_disabled, Boolean, required: false
      argument :subscription_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :usage_thresholds, [Types::UsageThresholds::Input], required: false
    end
  end
end
