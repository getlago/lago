# frozen_string_literal: true

module Types
  module WalletTransactions
    class Object < Types::BaseObject
      graphql_name "WalletTransaction"

      field :id, ID, null: false
      field :wallet, Types::Wallets::Object

      field :amount, String, null: false
      field :credit_amount, String, null: false
      field :invoice_requires_successful_payment, Boolean, null: false
      field :name, String, null: true
      field :priority, Integer, null: false
      field :source, Types::WalletTransactions::SourceEnum, null: false
      field :status, Types::WalletTransactions::StatusEnum, null: false
      field :transaction_status, Types::WalletTransactions::TransactionStatusEnum, null: false
      field :transaction_type, Types::WalletTransactions::TransactionTypeEnum, null: false
      field :wallet_name, String, null: true

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :failed_at, GraphQL::Types::ISO8601DateTime, null: true
      field :invoice, Types::Invoices::Object, null: true
      field :metadata, [Types::WalletTransactions::MetadataObject], null: true
      field :remaining_amount_cents, GraphQL::Types::BigInt, null: true
      field :remaining_credit_amount, String, null: true
      field :settled_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      field :voided_invoice, Types::Invoices::Object, null: true

      field :selected_invoice_custom_sections, [Types::InvoiceCustomSections::Object], null: true
      field :skip_invoice_custom_sections, Boolean

      def invoice
        object.invoice&.visible? ? object.invoice : nil
      end

      def wallet_name
        object.wallet.name
      end
    end
  end
end
