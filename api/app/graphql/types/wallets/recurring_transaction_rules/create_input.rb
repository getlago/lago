# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateRecurringTransactionRuleInput"

        argument :expiration_at, GraphQL::Types::ISO8601DateTime, required: false
        argument :granted_credits, String, required: false
        argument :grants_target_top_up, Boolean, required: false
        argument :ignore_paid_top_up_limits, Boolean, required: false
        argument :interval, Types::Wallets::RecurringTransactionRules::IntervalEnum, required: false
        argument :invoice_custom_section, Types::InvoiceCustomSections::ReferenceInput, required: false
        argument :invoice_requires_successful_payment, Boolean, required: false
        argument :method, Types::Wallets::RecurringTransactionRules::MethodEnum, required: false
        argument :paid_credits, String, required: false
        argument :started_at, GraphQL::Types::ISO8601DateTime, required: false
        argument :target_ongoing_balance, String, required: false
        argument :threshold_credits, String, required: false
        argument :transaction_metadata, [Types::Wallets::RecurringTransactionRules::TransactionMetadataInput], required: false
        argument :transaction_name, String, required: false
        argument :trigger, Types::Wallets::RecurringTransactionRules::TriggerEnum, required: true

        argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
      end
    end
  end
end
