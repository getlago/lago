# frozen_string_literal: true

module Types
  module Wallets
    class UpdateInput < Types::BaseInputObject
      description "Update Wallet Input"

      argument :billing_entity_id, ID, required: false
      argument :code, String, required: false
      argument :expiration_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :id, ID, required: true
      argument :invoice_requires_successful_payment, Boolean, required: false
      argument :name, String, required: false
      argument :priority, Integer, required: true

      argument :paid_top_up_max_amount_cents, GraphQL::Types::BigInt, required: false
      argument :paid_top_up_min_amount_cents, GraphQL::Types::BigInt, required: false

      argument :invoice_custom_section, Types::InvoiceCustomSections::ReferenceInput, required: false
      argument :recurring_transaction_rules, [Types::Wallets::RecurringTransactionRules::UpdateInput], required: false

      argument :applies_to, Types::Wallets::AppliesToInput, required: false

      argument :metadata, [Types::Metadata::Input], required: false, **Types::Metadata::Input::ARGUMENT_OPTIONS

      argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
    end
  end
end
