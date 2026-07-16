# frozen_string_literal: true

module Types
  module Analytics
    module InvoiceCollections
      class Object < Types::BaseObject
        graphql_name "FinalizedInvoiceCollection"

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :currency, Types::CurrencyEnum, null: true
        field :invoices_count, GraphQL::Types::BigInt, null: false
        field :month, GraphQL::Types::ISO8601DateTime, null: false
        field :payment_status, Types::Invoices::PaymentStatusTypeEnum, null: true
      end
    end
  end
end
