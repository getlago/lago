# frozen_string_literal: true

module Types
  module Payments
    class Object < Types::BaseObject
      graphql_name "Payment"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :amount_currency, Types::CurrencyEnum, null: false

      field :customer, Types::Customers::Object, null: false
      field :payable, Types::Payables::Object, null: false
      field :payable_payment_status, Types::Payments::PayablePaymentStatusEnum, null: true
      field :payment_method_id, ID, null: true
      field :payment_provider, Types::PaymentProviders::Object, null: true
      field :payment_provider_type, Types::PaymentProviders::ProviderTypeEnum, null: true
      field :payment_receipt, Types::PaymentReceipts::Object, null: true
      field :payment_type, Types::Payments::PaymentTypeEnum, null: false
      field :provider_payment_id, GraphQL::Types::String, null: true
      field :reference, GraphQL::Types::String, null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    end
  end
end
