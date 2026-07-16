# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class Object < Types::BaseObject
        graphql_name "RecurringTransactionRule"

        field :lago_id, ID, null: false, method: :id

        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :expiration_at, GraphQL::Types::ISO8601DateTime, null: true
        field :granted_credits, String, null: false
        field :grants_target_top_up, Boolean, null: true
        field :ignore_paid_top_up_limits, Boolean, null: false
        field :interval, Types::Wallets::RecurringTransactionRules::IntervalEnum, null: true
        field :invoice_requires_successful_payment, Boolean, null: false
        field :method, Types::Wallets::RecurringTransactionRules::MethodEnum, null: false, resolver_method: :resolver_method
        field :paid_credits, String, null: false
        field :payment_method, Types::PaymentMethods::Object
        field :payment_method_type, Types::PaymentMethods::MethodTypeEnum
        field :selected_invoice_custom_sections, [Types::InvoiceCustomSections::Object], null: true
        field :skip_invoice_custom_sections, Boolean
        field :started_at, GraphQL::Types::ISO8601DateTime, null: true
        field :target_ongoing_balance, String, null: true
        field :threshold_credits, String, null: true
        field :transaction_metadata, [Types::Wallets::RecurringTransactionRules::TransactionMetadataObject], null: true
        field :transaction_name, String, null: true
        field :trigger, Types::Wallets::RecurringTransactionRules::TriggerEnum, null: false

        def resolver_method
          object.method
        end
      end
    end
  end
end
