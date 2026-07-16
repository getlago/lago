# frozen_string_literal: true

module Types
  module Wallets
    class Object < Types::BaseObject
      graphql_name "Wallet"
      description "Wallet"

      field :id, ID, null: false

      field :billing_entity_id, ID, null: true
      field :customer, Types::Customers::Object

      field :code, String, null: true
      field :currency, Types::CurrencyEnum, null: false
      field :name, String, null: true
      field :priority, Integer, null: false
      field :status, Types::Wallets::StatusEnum, null: false

      field :rate_amount, GraphQL::Types::Float, null: false

      field :balance_cents, GraphQL::Types::BigInt, null: false
      field :consumed_amount_cents, GraphQL::Types::BigInt, null: false
      field :ongoing_balance_cents, GraphQL::Types::BigInt, null: false
      field :ongoing_usage_balance_cents, GraphQL::Types::BigInt, null: false

      field :consumed_credits, GraphQL::Types::Float, null: false
      field :credits_balance, GraphQL::Types::Float, null: false
      field :credits_ongoing_balance, GraphQL::Types::Float, null: false
      field :credits_ongoing_usage_balance, GraphQL::Types::Float, null: false

      field :last_balance_sync_at, GraphQL::Types::ISO8601DateTime, null: true
      field :last_consumed_credit_at, GraphQL::Types::ISO8601DateTime, null: true
      field :last_ongoing_balance_sync_at, GraphQL::Types::ISO8601DateTime, null: true

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :recurring_transaction_rules, [Types::Wallets::RecurringTransactionRules::Object], null: true

      field :invoice_requires_successful_payment, Boolean, null: false

      field :paid_top_up_max_amount_cents, GraphQL::Types::BigInt, null: true
      field :paid_top_up_max_credits, GraphQL::Types::BigInt, null: true
      field :paid_top_up_min_amount_cents, GraphQL::Types::BigInt, null: true
      field :paid_top_up_min_credits, GraphQL::Types::BigInt, null: true

      field :selected_invoice_custom_sections, [Types::InvoiceCustomSections::Object], null: true
      field :skip_invoice_custom_sections, Boolean

      field :payment_method, Types::PaymentMethods::Object
      field :payment_method_type, Types::PaymentMethods::MethodTypeEnum

      field :applies_to, Types::Wallets::AppliesTo, null: true, method: :itself

      field :metadata, [Types::Metadata::Object], null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :expiration_at, GraphQL::Types::ISO8601DateTime, null: true
      field :terminated_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :traceable, Boolean, null: false

      def recurring_transaction_rules
        object.recurring_transaction_rules.active
      end

      def metadata
        object.metadata&.value
      end
    end
  end
end
