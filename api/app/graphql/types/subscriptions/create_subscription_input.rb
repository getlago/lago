# frozen_string_literal: true

module Types
  module Subscriptions
    class CreateSubscriptionInput < BaseInputObject
      description "Create Subscription input arguments"

      argument :ending_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :external_id, String, required: false
      argument :name, String, required: false
      argument :subscription_id, ID, required: false

      argument :billing_entity_id, ID, required: false
      argument :customer_id, ID, required: true
      argument :invoice_custom_section, Types::InvoiceCustomSections::ReferenceInput, required: false
      argument :plan_id, ID, required: true
      argument :plan_overrides, Types::Subscriptions::PlanOverridesInput, required: false
      argument :usage_thresholds, [Types::UsageThresholds::Input], required: false

      argument :activation_rules, [Types::Subscriptions::ActivationRuleInput], required: false
      argument :billing_time, Types::Subscriptions::BillingTimeEnum, required: true
      argument :consolidate_invoice, Boolean, required: false
      argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
      argument :progressive_billing_disabled, Boolean, required: false
      argument :subscription_at, GraphQL::Types::ISO8601DateTime, required: false
    end
  end
end
